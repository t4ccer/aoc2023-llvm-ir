%.o: %.ll
	llc $^ -o $@ --filetype=obj -O3

%: %.o
	clang $^ -o $@ -static -fuse-ld=lld -O3

all: day1
