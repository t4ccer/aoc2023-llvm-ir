declare ptr @fopen(ptr noundef, ptr noundef) #1
declare i64 @fread(ptr noundef, i64 noundef, i64 noundef, ptr noundef) #1
declare i32 @fputs(ptr nocapture noundef readonly, ptr nocapture noundef) local_unnamed_addr #1
declare i32 @printf(ptr noundef, ...) #1

@stdout = external local_unnamed_addr constant ptr
@stderr = external local_unnamed_addr constant ptr

@str.usage = private unnamed_addr constant [8 x i8] c"Usage: \00"
@str.files = private unnamed_addr constant [9 x i8] c" <file>\0A\00"
@str.read_mode = private unnamed_addr constant [2 x i8] c"r\00"
@str.err_could_not_open = private unnamed_addr constant [27 x i8] c"Could not open input file\0A\00"
@str.err_buffer_too_small = private unnamed_addr constant [34 x i8] c"Could not fit file in the buffer\0A\00"
@str.print.part1 = private unnamed_addr constant [14 x i8] c"part 1: %lld\0A\00"
@str.print.part2 = private unnamed_addr constant [14 x i8] c"part 2: %lld\0A\00"

;; I know that challenge says that only I/O can be provided from libc
;; but this actually compiles down to a single `sqrtsd` so it's fine with me
declare double @sqrt(double noundef) local_unnamed_addr

define void @add.i64(ptr %dest, i64 %op) {
  %val = load i64, ptr %dest
  %incremented = add i64 %op, %val
  store i64 %incremented, ptr %dest, align 8
  ret void
}

define void @mul.i64(ptr %dest, i64 %op) {
  %val = load i64, ptr %dest
  %incremented = mul i64 %op, %val
  store i64 %incremented, ptr %dest, align 8
  ret void
}

define void @incr.i64(ptr %val) {
  %prev = load i64, ptr %val
  %incremented = add i64 1, %prev
  store i64 %incremented, ptr %val
  ret void
}

define i1 @is_digit(i8 %char) {
  %bounded_below = icmp ugt i8 %char, 47
  %bounded_above = icmp ult i8 %char, 58
  %in_range = and i1 %bounded_below, %bounded_above
  ret i1 %in_range
}

define i8 @get_char(ptr %buf, ptr %idx) {
  %idx_val = load i64, ptr %idx
  %char_ptr = getelementptr i8, ptr %buf, i64 %idx_val
  %char = load i8, ptr %char_ptr
  ret i8 %char
}

define i64 @parse.i64_with_spaces(ptr %buf, ptr %idx_ptr) {
  %acc = alloca i64
  store i64 0, ptr %acc

  br label %loop_start

loop_start:
  %idx_val = load i64, ptr %idx_ptr
  %buf_ptr = getelementptr i8, ptr %buf, i64 %idx_val
  %char = load i8, ptr %buf_ptr
  %is_valid_digit = call fastcc i1 @is_digit(i8 %char)
  br i1 %is_valid_digit, label %is_digit, label %is_not_digit

is_digit:
  call fastcc void @incr.i64(ptr %idx_ptr)

  %digit.i8 = sub i8 %char, 48
  %digit = sext i8 %digit.i8 to i64

  %acc.0 = load i64, ptr %acc
  %acc.1 = mul i64 10, %acc.0
  %acc.2 = add i64 %digit, %acc.1
  store i64 %acc.2, ptr %acc

  br label %loop_start

is_not_digit:
  %is_space = icmp eq i8 %char, 32
  br i1 %is_space, label %space, label %not_space

space:
  call fastcc void @incr.i64(ptr %idx_ptr)
  br label %loop_start

not_space:

  %acc.final = load i64, ptr %acc
  ret i64 %acc.final
}

define i64 @parse.i64(ptr %buf, ptr %idx_ptr) {
  %acc = alloca i64
  store i64 0, ptr %acc

  br label %loop_start

loop_start:
  %idx_val = load i64, ptr %idx_ptr
  %buf_ptr = getelementptr i8, ptr %buf, i64 %idx_val
  %char = load i8, ptr %buf_ptr
  %is_valid_digit = call fastcc i1 @is_digit(i8 %char)
  br i1 %is_valid_digit, label %is_digit, label %is_not_digit

is_digit:
  call fastcc void @incr.i64(ptr %idx_ptr)

  %digit.i8 = sub i8 %char, 48
  %digit = sext i8 %digit.i8 to i64

  %acc.0 = load i64, ptr %acc
  %acc.1 = mul i64 10, %acc.0
  %acc.2 = add i64 %digit, %acc.1
  store i64 %acc.2, ptr %acc

  br label %loop_start

is_not_digit:
  %acc.final = load i64, ptr %acc
  ret i64 %acc.final
}

define i1 @char_eq(ptr %buf, ptr %idx, i8 %expected) {
  %char = call fastcc i8 @get_char(ptr %buf, ptr %idx)
  %matches = icmp eq i8 %expected, %char
  ret i1 %matches
}

define void @skip_to(ptr %buf, ptr %idx, i8 %target) {
  br label %loop_start
loop_start:
  %matches = call fastcc i1 @char_eq(ptr %buf, ptr %idx, i8 %target)
  call fastcc void @incr.i64(ptr %idx)
  br i1 %matches, label %quit, label %loop_start

quit:
  ret void
}

define void @skip_spaces(ptr %buf, ptr %idx) {
  br label %loop_start
loop_start:
  %is_space = call fastcc i1 @char_eq(ptr %buf, ptr %idx, i8 32)
  br i1 %is_space, label %space, label %quit

space:
  call fastcc void @incr.i64(ptr %idx)
  br label %loop_start

quit:
  ret void
}

define i64 @floor_minus(double %num) {
  %num_part.i64 = fptosi double %num to i64
  %num_part = sitofp i64 %num_part.i64 to double
  %are_eq = fcmp ueq double %num_part, %num
  br i1 %are_eq, label %eq, label %not_eq

eq:
 %ans = sub i64 %num_part.i64, 1
  ret i64 %ans

not_eq:
  ret i64 %num_part.i64
}

define i64 @solve_race(i64 %time, i64 %distance) {
  ;; p = 1/2(t +- sqrt(t^2 - 4d))
  %time.double = sitofp i64 %time to double
  %distance.double = sitofp i64 %distance to double

  %tmp.4d = mul i64 4, %distance
  %tmp.tt = mul i64 %time, %time
  %tmp.under_root = sub i64 %tmp.tt, %tmp.4d
  %tmp.under_root.double = sitofp i64 %tmp.under_root to double
  %tmp.root.double = tail call double @sqrt(double noundef %tmp.under_root.double)

  %tmp.bracket.left = fsub double %time.double, %tmp.root.double
  %tmp.left.double = fmul double %tmp.bracket.left, 0.5
  %tmp.left.0 = fptosi double %tmp.left.double to i64
  %tmp.left = add i64 1, %tmp.left.0

  %tmp.bracket.right = fadd double %time.double, %tmp.root.double
  %tmp.right.double = fmul double %tmp.bracket.right, 0.5
  %tmp.right = call fastcc i64 @floor_minus(double %tmp.right.double)

  %tmp.diff = sub i64 %tmp.right, %tmp.left
  %ans = add i64 1, %tmp.diff
  ret i64 %ans
}

define i64 @part_1(ptr %buf) {
  %acc = alloca i64
  store i64 1, ptr %acc

  %time_idx = alloca i64
  store i64 9, ptr %time_idx
  call fastcc void @skip_spaces(ptr %buf, ptr %time_idx)

  %distance_idx = alloca i64
  store i64 0, ptr %distance_idx
  call fastcc void @skip_to(ptr %buf, ptr %distance_idx, i8 10)
  call fastcc void @add.i64(ptr %distance_idx, i64 9)
  call fastcc void @skip_spaces(ptr %buf, ptr %distance_idx)

  br label %loop_start

loop_start:
  %is_eol = call fastcc i1 @char_eq(ptr %buf, ptr %time_idx, i8 10)
  br i1 %is_eol, label %loop_end, label %loop_cont

loop_cont:
  %t = call fastcc i64 @parse.i64(ptr %buf, ptr %time_idx)
  call fastcc void @skip_spaces(ptr %buf, ptr %time_idx)

  %d = call fastcc i64 @parse.i64(ptr %buf, ptr %distance_idx)
  call fastcc void @skip_spaces(ptr %buf, ptr %distance_idx)

  %ans = call fastcc i64 @solve_race(i64 %t, i64 %d)
  call fastcc void @mul.i64(ptr %acc, i64 %ans)

  br label %loop_start

loop_end:
  %final = load i64, ptr %acc
  ret i64 %final
}

define i64 @part_2(ptr %buf) {
  %time_idx = alloca i64
  store i64 9, ptr %time_idx
  call fastcc void @skip_spaces(ptr %buf, ptr %time_idx)

  %distance_idx = alloca i64
  store i64 0, ptr %distance_idx
  call fastcc void @skip_to(ptr %buf, ptr %distance_idx, i8 10)
  call fastcc void @add.i64(ptr %distance_idx, i64 9)
  call fastcc void @skip_spaces(ptr %buf, ptr %distance_idx)

  %t = call fastcc i64 @parse.i64_with_spaces(ptr %buf, ptr %time_idx)
  %d = call fastcc i64 @parse.i64_with_spaces(ptr %buf, ptr %distance_idx)
  %ans = call fastcc i64 @solve_race(i64 %t, i64 %d)
  ret i64 %ans
}

define i32 @main(i32 %argc, ptr %argv) local_unnamed_addr #0 {
  %stderr = load ptr, ptr @stderr
  %stdout = load ptr, ptr @stdout

  %prog_name_ptr = getelementptr ptr, ptr %argv, i64 0
  %prog_name = load ptr, ptr %prog_name_ptr

  %correct_usage = icmp eq i32 2, %argc
  br i1 %correct_usage, label %file_provided, label %show_usage

show_usage:
  call i32 @fputs(ptr @str.usage, ptr %stderr)
  call i32 @fputs(ptr %prog_name, ptr %stderr)
  call i32 @fputs(ptr @str.files, ptr %stderr)
  ret i32 1

file_provided:
  %fp_ptr = getelementptr ptr, ptr %argv, i64 1
  %fp = load ptr, ptr %fp_ptr
  %fd = call ptr @fopen(ptr %fp, ptr @str.read_mode)
  %opend_correctly = icmp ne ptr %fd, null
  br i1 %opend_correctly, label %read_file, label %invalid_file

invalid_file:
  call i32 @fputs(ptr @str.err_could_not_open, ptr %stderr)
  ret i32 1

read_file:
  %buf = alloca [65536 x i8]
  %read_bytes = call i64 @fread(ptr %buf, i64 1, i64 65535, ptr %fd)
  %read_everything = icmp eq i64 65535, %read_bytes
  br i1 %read_everything, label %buffer_too_small, label %process_file

buffer_too_small:
  call i32 @fputs(ptr @str.err_buffer_too_small, ptr %stderr)
  ret i32 1

process_file:
  %last_char = getelementptr i8, ptr %buf, i64 %read_bytes
  store i8 0, ptr %last_char

  %part_1_answer = call fastcc i64 @part_1(ptr %buf)
  call i32 @printf(ptr @str.print.part1, i64 %part_1_answer)

  %part_2_answer = call fastcc i64 @part_2(ptr %buf)
  call i32 @printf(ptr @str.print.part2, i64 %part_2_answer)

  ret i32 0
}
