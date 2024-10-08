run:
	zig run ./src/main.zig

run/log:
	zig run ./src/main.zig 2> log.txt

log:
	clear && tail -f log.txt
