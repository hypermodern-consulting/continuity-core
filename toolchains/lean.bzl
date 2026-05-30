# Lean 4 compilation rules for Buck2
# Handles hierarchical module structure (Continuity.Build.Triple etc.)

LeanLibraryInfo = provider(fields = {
    "olean_dir": provider_field(Artifact | None, default = None),
    "c_dir": provider_field(Artifact | None, default = None),
    "lib_name": provider_field(str, default = ""),
})

def _get_lean():
    path = read_root_config("lean", "lean", None)
    if path == None:
        fail("lean compiler not configured. Set [lean] lean = ... in .buckconfig")
    return path

def _get_leanc():
    path = read_root_config("lean", "leanc", None)
    if path == None:
        fail("leanc not configured. Set [lean] leanc = ... in .buckconfig")
    return path

def _get_lean_lib_dir():
    return read_root_config("lean", "lean_lib_dir", None)

def _lean_library_impl(ctx: AnalysisContext) -> list[Provider]:
    lean = _get_lean()
    lean_lib_dir = _get_lean_lib_dir()

    olean_dir = ctx.actions.declare_output("olean", dir = True)
    c_dir = ctx.actions.declare_output("c", dir = True)

    # Build LEAN_PATH
    lean_path_parts = ["$OLEAN_DIR", "$BUCK_SCRATCH_PATH"]
    if lean_lib_dir:
        lean_path_parts.append(lean_lib_dir)

    for dep in ctx.attrs.deps:
        if LeanLibraryInfo in dep:
            info = dep[LeanLibraryInfo]
            if info.olean_dir:
                lean_path_parts.append(cmd_args(info.olean_dir))

    script_parts = ["set -e"]
    script_parts.append("mkdir -p $OLEAN_DIR $C_DIR")
    script_parts.append(cmd_args(
        "export LEAN_PATH=",
        cmd_args(lean_path_parts, delimiter = ":"),
        delimiter = "",
    ))

    # Key fix: preserve full directory hierarchy using short_path
    for src in ctx.attrs.srcs:
        # src.short_path gives us e.g. "Continuity/Build/Triple.lean"
        rel_path = src.short_path
        rel_dir = "/".join(rel_path.split("/")[:-1])

        # Create directory structure in scratch and olean dirs
        if rel_dir:
            script_parts.append("mkdir -p $BUCK_SCRATCH_PATH/{} $OLEAN_DIR/{}".format(rel_dir, rel_dir))

        # Copy preserving hierarchy
        script_parts.append(cmd_args(
            "cp",
            src,
            "$BUCK_SCRATCH_PATH/{}".format(rel_path),
            delimiter = " ",
        ))

        # Compile
        olean_path = "$OLEAN_DIR/{}".format(rel_path.removesuffix(".lean") + ".olean")
        c_path = "$C_DIR/{}".format(rel_path.replace("/", ".").removesuffix(".lean") + ".c")

        compile_cmd = [
            lean,
            "--root=$BUCK_SCRATCH_PATH",
            "-o",
            olean_path,
            "--c={}".format(c_path),
            "$BUCK_SCRATCH_PATH/{}".format(rel_path),
        ]
        script_parts.append(cmd_args(compile_cmd, delimiter = " "))

    script = cmd_args(script_parts, delimiter = "\n")

    ctx.actions.run(
        cmd_args(
            "/bin/sh",
            "-c",
            cmd_args(
                "OLEAN_DIR=",
                olean_dir.as_output(),
                " C_DIR=",
                c_dir.as_output(),
                " && ",
                script,
                delimiter = "",
            ),
        ),
        category = "lean_compile",
        identifier = ctx.attrs.name,
    )

    return [
        DefaultInfo(default_output = olean_dir),
        LeanLibraryInfo(
            olean_dir = olean_dir,
            c_dir = c_dir,
            lib_name = ctx.attrs.name,
        ),
    ]

def _lean_binary_impl(ctx: AnalysisContext) -> list[Provider]:
    lean = _get_lean()
    leanc = _get_leanc()
    lean_lib_dir = _get_lean_lib_dir()

    exe = ctx.actions.declare_output(ctx.attrs.name)
    olean_dir = ctx.actions.declare_output("olean", dir = True)
    c_dir = ctx.actions.declare_output("c", dir = True)

    # Collect dep olean/c dirs
    dep_olean_dirs = []
    dep_c_dirs = []
    for dep in ctx.attrs.deps:
        if LeanLibraryInfo in dep:
            info = dep[LeanLibraryInfo]
            if info.olean_dir:
                dep_olean_dirs.append(info.olean_dir)
            if info.c_dir:
                dep_c_dirs.append(info.c_dir)

    lean_path_parts = ["$BUCK_SCRATCH_PATH", "$OLEAN_DIR"]
    if lean_lib_dir:
        lean_path_parts.append(lean_lib_dir)
    for d in dep_olean_dirs:
        lean_path_parts.append(cmd_args(d))

    script_parts = ["set -e"]
    script_parts.append("mkdir -p $OLEAN_DIR $C_DIR")
    script_parts.append(cmd_args(
        "export LEAN_PATH=",
        cmd_args(lean_path_parts, delimiter = ":"),
        delimiter = "",
    ))

    # Copy dep oleans into scratch so lean's --root resolution finds them
    for d in dep_olean_dirs:
        script_parts.append(cmd_args(
            "cp -rn",
            cmd_args(d, "/.", delimiter = ""),
            "$BUCK_SCRATCH_PATH/",
            delimiter = " ",
        ))

    c_files = []
    for src in ctx.attrs.srcs:
        rel_path = src.short_path
        rel_dir = "/".join(rel_path.split("/")[:-1])

        if rel_dir:
            script_parts.append("mkdir -p $BUCK_SCRATCH_PATH/{} $OLEAN_DIR/{}".format(rel_dir, rel_dir))

        script_parts.append(cmd_args(
            "cp",
            src,
            "$BUCK_SCRATCH_PATH/{}".format(rel_path),
            delimiter = " ",
        ))

        c_file = "$C_DIR/{}".format(rel_path.replace("/", ".").removesuffix(".lean") + ".c")
        olean_path = "$OLEAN_DIR/{}".format(rel_path.removesuffix(".lean") + ".olean")
        c_files.append(c_file)

        compile_cmd = [
            lean,
            "--root=$BUCK_SCRATCH_PATH",
            "-o",
            olean_path,
            "--c={}".format(c_file),
            "$BUCK_SCRATCH_PATH/{}".format(rel_path),
        ]
        script_parts.append(cmd_args(compile_cmd, delimiter = " "))

    # Link — include both binary C files and dep library C files
    link_parts = [leanc, "-o", cmd_args(exe.as_output())]
    for c_file in c_files:
        link_parts.append(c_file)

    # Add dep C files via find
    for d in dep_c_dirs:
        script_parts.append(cmd_args("DEP_C_FILES=\"$(find ", d, " -name '*.c')\"", delimiter = ""))
    link_parts.append("$DEP_C_FILES")
    script_parts.append(cmd_args(link_parts, delimiter = " "))

    script = cmd_args(script_parts, delimiter = "\n")

    hidden = list(ctx.attrs.srcs)
    hidden.extend(dep_olean_dirs)
    hidden.extend(dep_c_dirs)

    ctx.actions.run(
        cmd_args(
            "/bin/sh",
            "-c",
            cmd_args(
                "OLEAN_DIR=",
                olean_dir.as_output(),
                " C_DIR=",
                c_dir.as_output(),
                " && ",
                script,
                delimiter = "",
            ),
            hidden = hidden,
        ),
        category = "lean_link",
        identifier = ctx.attrs.name,
    )

    return [
        DefaultInfo(default_output = exe),
        RunInfo(args = cmd_args(exe)),
    ]

lean_library = rule(
    impl = _lean_library_impl,
    attrs = {
        "srcs": attrs.list(attrs.source()),
        "deps": attrs.list(attrs.dep(), default = []),
        "lean_flags": attrs.list(attrs.string(), default = []),
    },
)

lean_binary = rule(
    impl = _lean_binary_impl,
    attrs = {
        "srcs": attrs.list(attrs.source()),
        "deps": attrs.list(attrs.dep(), default = []),
        "lean_flags": attrs.list(attrs.string(), default = []),
        "link_flags": attrs.list(attrs.string(), default = []),
    },
)
