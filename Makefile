.PHONY: build run clean check

build:
	lake build

run:
	lake exe continuity

clean:
	lake clean
	rm -rf .lake

# Check: build and verify no sorry in the codebase
check: build
	@echo "--- sorry audit ---"
	@grep -rn 'sorry' Continuity/ --include='*.lean' || echo "0 sorry. clean."
	@echo ""
	@grep -rn 'axiom ' Continuity/ --include='*.lean' | grep -v '^--' || echo "0 axioms."
