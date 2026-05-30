# CUDA compilation rules for Buck2
# Requires [nv] section in .buckconfig:
#   nvcc = /usr/local/cuda/bin/nvcc
#   cuda_root = /usr/local/cuda

def _get_nvcc():
    path = read_root_config("nv", "nvcc", None)
    if path == None:
        fail("nvcc not configured. Set [nv] nvcc = ... in .buckconfig")
    return path

def _get_cuda_root():
    return read_root_config("nv", "cuda_root", None)

def _get_cc():
    return read_root_config("cxx", "cc", "gcc")

def _cuda_library_impl(ctx: AnalysisContext) -> list[Provider]:
    nvcc = _get_nvcc()
    cuda_root = _get_cuda_root()
    cc = _get_cc()

    obj_dir = ctx.actions.declare_output("obj", dir = True)

    script_parts = ["set -e", "mkdir -p $OBJ_DIR"]

    nvcc_flags = ["-c", "--compiler-options", "'-fPIC'"]
    for flag in ctx.attrs.nvcc_flags:
        nvcc_flags.append(flag)

    if cuda_root:
        nvcc_flags.extend(["-I", cuda_root + "/include"])

    for arch in ctx.attrs.gpu_archs:
        nvcc_flags.extend(["-gencode", "arch=compute_{0},code=sm_{0}".format(arch)])

    obj_files = []
    for src in ctx.attrs.srcs:
        rel_path = src.short_path
        obj_name = rel_path.replace("/", "_").removesuffix(".cu") + ".o"
        obj_path = "$OBJ_DIR/" + obj_name

        # Copy source preserving hierarchy
        rel_dir = "/".join(rel_path.split("/")[:-1])
        if rel_dir:
            script_parts.append("mkdir -p $BUCK_SCRATCH_PATH/{}".format(rel_dir))
        script_parts.append(cmd_args("cp", src, "$BUCK_SCRATCH_PATH/{}".format(rel_path), delimiter = " "))

        compile_cmd = [nvcc] + nvcc_flags + ["-o", obj_path, "$BUCK_SCRATCH_PATH/{}".format(rel_path)]
        script_parts.append(cmd_args(compile_cmd, delimiter = " "))
        obj_files.append(obj_path)

    script = cmd_args(script_parts, delimiter = "\n")

    ctx.actions.run(
        cmd_args(
            "/bin/sh",
            "-c",
            cmd_args("OBJ_DIR=", obj_dir.as_output(), " && ", script, delimiter = ""),
            hidden = list(ctx.attrs.srcs),
        ),
        category = "cuda_compile",
        identifier = ctx.attrs.name,
    )

    return [
        DefaultInfo(default_output = obj_dir),
    ]

def _cuda_binary_impl(ctx: AnalysisContext) -> list[Provider]:
    nvcc = _get_nvcc()
    cuda_root = _get_cuda_root()
    cc = _get_cc()

    exe = ctx.actions.declare_output(ctx.attrs.name)
    obj_dir = ctx.actions.declare_output("obj", dir = True)

    script_parts = ["set -e", "mkdir -p $OBJ_DIR"]

    nvcc_flags = ["-c", "--compiler-options", "'-fPIC'"]
    if cuda_root:
        nvcc_flags.extend(["-I", cuda_root + "/include"])
    for arch in ctx.attrs.gpu_archs:
        nvcc_flags.extend(["-gencode", "arch=compute_{0},code=sm_{0}".format(arch)])

    obj_files = []
    for src in ctx.attrs.srcs:
        rel_path = src.short_path
        obj_name = rel_path.replace("/", "_").removesuffix(".cu") + ".o"
        obj_path = "$OBJ_DIR/" + obj_name

        rel_dir = "/".join(rel_path.split("/")[:-1])
        if rel_dir:
            script_parts.append("mkdir -p $BUCK_SCRATCH_PATH/{}".format(rel_dir))
        script_parts.append(cmd_args("cp", src, "$BUCK_SCRATCH_PATH/{}".format(rel_path), delimiter = " "))

        compile_cmd = [nvcc] + nvcc_flags + ["-o", obj_path, "$BUCK_SCRATCH_PATH/{}".format(rel_path)]
        script_parts.append(cmd_args(compile_cmd, delimiter = " "))
        obj_files.append(obj_path)

    # Link
    link_flags = ["-lcudart"]
    if cuda_root:
        link_flags.extend(["-L", cuda_root + "/lib"])
        link_flags.extend(["-L", cuda_root + "/lib64"])
    for flag in ctx.attrs.link_flags:
        link_flags.append(flag)

    # Collect dep objects
    dep_obj_dirs = []
    for dep in ctx.attrs.deps:
        info = dep[DefaultInfo]
        if info.default_output:
            dep_obj_dirs.append(info.default_output)

    link_parts = [nvcc, "-o", cmd_args(exe.as_output())]
    for obj in obj_files:
        link_parts.append(obj)
    for d in dep_obj_dirs:
        script_parts.append(cmd_args("DEP_OBJS=\"`find ", d, " -name '*.o'`\"", delimiter = ""))
    link_parts.append("$DEP_OBJS")
    link_parts.extend(link_flags)

    script_parts.append(cmd_args(link_parts, delimiter = " "))

    script = cmd_args(script_parts, delimiter = "\n")

    hidden = list(ctx.attrs.srcs)
    hidden.extend(dep_obj_dirs)

    ctx.actions.run(
        cmd_args(
            "/bin/sh",
            "-c",
            cmd_args("OBJ_DIR=", obj_dir.as_output(), " && ", script, delimiter = ""),
            hidden = hidden,
        ),
        category = "cuda_link",
        identifier = ctx.attrs.name,
    )

    return [
        DefaultInfo(default_output = exe),
        RunInfo(args = cmd_args(exe)),
    ]

cuda_library = rule(
    impl = _cuda_library_impl,
    attrs = {
        "srcs": attrs.list(attrs.source()),
        "deps": attrs.list(attrs.dep(), default = []),
        "gpu_archs": attrs.list(attrs.string(), default = ["90"]),
        "nvcc_flags": attrs.list(attrs.string(), default = []),
    },
)

cuda_binary = rule(
    impl = _cuda_binary_impl,
    attrs = {
        "srcs": attrs.list(attrs.source()),
        "deps": attrs.list(attrs.dep(), default = []),
        "gpu_archs": attrs.list(attrs.string(), default = ["90"]),
        "link_flags": attrs.list(attrs.string(), default = []),
    },
)
