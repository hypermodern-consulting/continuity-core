import MyLib.Greet
def main : IO Unit := do
  IO.println (greet "buck2")
  IO.println s!"2 + 3 = {add 2 3}"
