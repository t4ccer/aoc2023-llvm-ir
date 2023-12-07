%.o: %.ll
	llc $^ -o $@ --filetype=obj -O3

%: %.o
	clang $^ -o $@ -static -fuse-ld=lld -O3

SOURCES := $(wildcard day*.ll)

.PHONY: all
.DEFAULT_GOAL := all
all: $(patsubst %.ll,%,$(SOURCES))

.PHONY: clean
clean:
	rm -f $(patsubst %.ll,%,$(SOURCES)) $(patsubst %.ll,%.o,$(SOURCES))

.PHONY: time
time: all
	for d in $(patsubst %.ll,%,$(SOURCES)); do	\
		echo "$$d:";				\
		time ./$$d ./inputs/$$d.txt ;		\
		echo "";				\
	done
