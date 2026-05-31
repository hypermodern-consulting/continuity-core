#!/usr/bin/env python3
"""Convert a .bzl file to a Lean BzlFile definition.

Reads the .bzl file, extracts structure (loads, providers, helpers, rules),
and outputs Lean code defining the BzlFile value with impl bodies as strings.
"""

import re
import sys
from pathlib import Path

def escape_lean(s: str) -> str:
    """Escape a string for Lean string literal."""
    return s.replace('\\', '\\\\').replace('"', '\\"').replace('\n', '\\n')

def extract_loads(lines: list[str]) -> list[tuple[str, list[str]]]:
    """Extract load() statements."""
    loads = []
    i = 0
    while i < len(lines):
        line = lines[i].strip()
        if line.startswith('load('):
            # Collect multi-line load
            load_text = ''
            while i < len(lines):
                load_text += lines[i]
                if ')' in lines[i]:
                    break
                i += 1
            # Parse: load("path", "sym1", "sym2", ...)
            m = re.search(r'load\(\s*"([^"]+)"', load_text)
            if m:
                bzl_path = m.group(1)
                symbols = re.findall(r'"([^"]+)"', load_text)[1:]  # skip path
                loads.append((bzl_path, symbols))
        i += 1
    return loads

def extract_providers(lines: list[str]) -> list[tuple[str, list[str]]]:
    """Extract provider definitions (just names + field names)."""
    providers = []
    i = 0
    while i < len(lines):
        m = re.match(r'^(\w+)\s*=\s*provider\(', lines[i])
        if m:
            name = m.group(1)
            # Collect the full provider definition
            prov_text = ''
            while i < len(lines):
                prov_text += lines[i]
                if lines[i].strip().endswith(')') or lines[i].strip().endswith('})'):
                    break
                i += 1
            # Extract field names
            fields = re.findall(r'"(\w+)":\s*provider_field', prov_text)
            providers.append((name, fields))
        i += 1
    return providers

def extract_functions(lines: list[str]) -> list[tuple[str, list[str], str]]:
    """Extract all def functions with their bodies."""
    functions = []
    i = 0
    while i < len(lines):
        m = re.match(r'^def (\w+)\((.*)$', lines[i])
        if m:
            fname = m.group(1)
            # Parse params from first line
            param_line = m.group(2)
            # Collect full signature (might span multiple lines)
            while i < len(lines) and ':' not in lines[i].split('#')[0].split('"""')[0][-5:] if ')' not in lines[i] else False:
                i += 1
            
            # Collect body (everything indented after the def line)
            # Must track triple-quoted strings since their content can be unindented
            body_lines = []
            i += 1
            in_triple_quote = False
            while i < len(lines):
                line = lines[i]
                stripped = line.strip()
                
                # Track triple-quote state
                tq_count = line.count('"""')
                if tq_count % 2 == 1:  # odd number of """ toggles state
                    in_triple_quote = not in_triple_quote
                
                if in_triple_quote:
                    # Inside triple-quoted string — include everything
                    body_lines.append(line.rstrip())
                elif stripped == '':
                    body_lines.append('')
                elif line[0] == ' ' or line[0] == '\t':
                    body_lines.append(line.rstrip())
                else:
                    break
                i += 1
            
            # Strip trailing empty lines
            while body_lines and body_lines[-1] == '':
                body_lines.pop()
            
            # Parse params
            full_sig = lines[m.start():i]
            params_match = re.search(r'\(([^)]*)\)', ''.join(l.strip() for l in full_sig[:3]))
            params = []
            if params_match:
                for p in params_match.group(1).split(','):
                    p = p.strip()
                    if p:
                        # Remove type annotations
                        pname = p.split(':')[0].strip()
                        if pname:
                            params.append(pname)
            
            functions.append((fname, params, '\n'.join(body_lines)))
        else:
            i += 1
    return functions

def extract_rules(lines: list[str]) -> list[tuple[str, str, bool, list[tuple[str, str]]]]:
    """Extract rule() definitions: (name, impl_name, is_toolchain, [(attr_name, attr_type_raw)])"""
    rules = []
    i = 0
    while i < len(lines):
        m = re.match(r'^(\w+)\s*=\s*rule\(', lines[i])
        if m:
            rule_name = m.group(1)
            # Collect full rule definition
            rule_text = ''
            depth = 0
            while i < len(lines):
                rule_text += lines[i] + '\n'
                depth += lines[i].count('(') - lines[i].count(')')
                if depth <= 0 and rule_text.count('(') > 0:
                    break
                i += 1
            
            # Extract impl function name
            impl_match = re.search(r'impl\s*=\s*(\w+)', rule_text)
            impl_name = impl_match.group(1) if impl_match else ''
            
            # Check is_toolchain_rule
            is_toolchain = 'is_toolchain_rule = True' in rule_text
            
            # Extract attrs with balanced parentheses
            attrs = []
            for am in re.finditer(r'"(\w+)":\s*', rule_text):
                aname = am.group(1)
                # Find the balanced attr type expression
                rest = rule_text[am.end():]
                depth = 0
                end = 0
                for j, ch in enumerate(rest):
                    if ch == '(':
                        depth += 1
                    elif ch == ')':
                        depth -= 1
                        if depth == 0:
                            end = j + 1
                            break
                    elif ch in (',', '\n', '}') and depth == 0:
                        end = j
                        break
                atype = rest[:end].strip().rstrip(',')
                if atype.startswith('attrs.'):
                    attrs.append((aname, atype))
            
            rules.append((rule_name, impl_name, is_toolchain, attrs))
        i += 1
    return rules

def to_lean_bzlfile(name: str, bzl_path: str, lines: list[str]) -> str:
    """Generate Lean BzlFile definition."""
    loads = extract_loads(lines)
    providers = extract_providers(lines)
    functions = extract_functions(lines)
    rules = extract_rules(lines)
    
    # Map impl names to their bodies
    func_bodies = {f[0]: f[2] for f in functions}
    
    # Separate helpers from impl functions
    impl_names = {r[1] for r in rules}
    helpers = [(f[0], f[1], f[2]) for f in functions if f[0] not in impl_names]
    
    out = []
    
    # Header comment
    header_lines = []
    for line in lines:
        if line.startswith('#'):
            header_lines.append(line.rstrip())
        elif line.strip() == '':
            continue
        else:
            break
    
    # Emit impl bodies as named defs
    for rule_name, impl_name, is_tc, attrs in rules:
        body = func_bodies.get(impl_name, '')
        if body:
            out.append(f'private def {name}_{rule_name}_body : String :=')
            body_lines = body.split('\n')
            lean_lines = []
            for bl in body_lines:
                escaped = escape_lean(bl)
                lean_lines.append(f'  "{escaped}"')
            out.append('  String.intercalate "\\n" [')
            out.append(',\n'.join(f'    {l.strip()}' for l in lean_lines))
            out.append('  ]')
            out.append('')
    
    # Emit helper bodies
    for hname, hparams, hbody in helpers:
        out.append(f'private def {name}_{hname}_body : String :=')
        body_lines = hbody.split('\n')
        lean_lines = []
        for bl in body_lines:
            escaped = escape_lean(bl)
            lean_lines.append(f'"{escaped}"')
        out.append('  String.intercalate "\\n" [')
        out.append(',\n'.join(f'    {l}' for l in lean_lines))
        out.append('  ]')
        out.append('')
    
    # Emit the BzlFile definition
    out.append(f'def {name}Bzl : BzlFile :=')
    
    # Header
    out.append('  { header := String.intercalate "\\n"')
    out.append(f'      [ "# toolchains/{bzl_path} — generated by continuity" ]')
    
    # Loads
    out.append('  , loads :=')
    for bzl, syms in loads:
        sym_list = ', '.join(f'"{s}"' for s in syms)
        out.append(f'      [ ⟨"{escape_lean(bzl)}", [{sym_list}]⟩')
        break
    for bzl, syms in loads[1:]:
        sym_list = ', '.join(f'"{s}"' for s in syms)
        out.append(f'      , ⟨"{escape_lean(bzl)}", [{sym_list}]⟩')
    out.append('      ]')
    
    # Providers
    if providers:
        out.append('  , providers :=')
        first = True
        for pname, pfields in providers:
            field_list = ', '.join(f'.simple "{f}"' for f in pfields)
            prefix = '      [ ' if first else '      , '
            out.append(f'{prefix}⟨"{pname}", [{field_list}]⟩')
            first = False
        out.append('      ]')
    
    # Helpers
    if helpers:
        out.append('  , helpers :=')
        first = True
        for hname, hparams, _ in helpers:
            params_list = ', '.join(f'"{p}"' for p in hparams)
            prefix = '      [ ' if first else '      , '
            out.append(f'{prefix}{{ name := "{hname}"')
            out.append(f'        , params := [{params_list}]')
            out.append(f'        , body := {name}_{hname}_body }}')
            first = False
        out.append('      ]')
    
    # Rules
    out.append('  , rules :=')
    first = True
    for rule_name, impl_name, is_tc, attrs in rules:
        prefix = '      [ ' if first else '      , '
        out.append(f'{prefix}{{ impl :=')
        out.append(f'            {{ name := "{impl_name}"')
        out.append(f'            , body := {name}_{rule_name}_body')
        out.append(f'            , is_toolchain := {"true" if is_tc else "false"} }}')
        out.append(f'        , attrs :=')
        
        # Attrs
        afirst = True
        for aname, atype_raw in attrs:
            aprefix = '            [ ' if afirst else '            , '
            out.append(f'{aprefix}⟨"{aname}", .raw "{escape_lean(atype_raw)}", ""⟩')
            afirst = False
        if not attrs:
            out.append('            [')
        out.append('            ] }}')
        first = False
    out.append('      ]')
    
    out.append('  }')
    
    return '\n'.join(out)


if __name__ == '__main__':
    if len(sys.argv) < 3:
        print(f"Usage: {sys.argv[0]} <name> <file.bzl>", file=sys.stderr)
        sys.exit(1)
    
    name = sys.argv[1]
    path = sys.argv[2]
    lines = open(path).readlines()
    print(to_lean_bzlfile(name, Path(path).name, lines))
