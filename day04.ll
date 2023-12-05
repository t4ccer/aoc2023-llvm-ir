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

%struct.gear = type { i64, i64, i64 }

define void @add.i64(ptr %dest, i64 %op) {
  %val = load i64, ptr %dest
  %incremented = add i64 %op, %val
  store i64 %incremented, ptr %dest, align 8
  ret void
}

define void @incr.i64(ptr %val) {
  %prev = load i64, ptr %val
  %incremented = add i64 1, %prev
  store i64 %incremented, ptr %val
  ret void
}

define i1 @is_digit(i8 %chr) {
  %bounded_below = icmp ugt i8 %chr, 47
  %bounded_above = icmp ult i8 %chr, 58
  %in_range = and i1 %bounded_below, %bounded_above
  ret i1 %in_range
}

define i8 @get_char(ptr %buf, ptr %idx) {
  %idx_val = load i64, ptr %idx
  %chr_ptr = getelementptr i8, ptr %buf, i64 %idx_val
  %chr = load i8, ptr %chr_ptr
  ret i8 %chr
}

define i64 @parse_i64(ptr %buf, ptr %idx_ptr) {
  %acc = alloca i64
  store i64 0, ptr %acc

  br label %loop_start

loop_start:
  %idx_val = load i64, ptr %idx_ptr
  %buf_ptr = getelementptr i8, ptr %buf, i64 %idx_val
  %chr = load i8, ptr %buf_ptr
  %is_valid_digit = call fastcc i1 @is_digit(i8 %chr)
  br i1 %is_valid_digit, label %is_digit, label %is_not_digit

is_digit:
  call fastcc void @incr.i64(ptr %idx_ptr)

  %digit.i8 = sub i8 %chr, 48
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
  %chr = call fastcc i8 @get_char(ptr %buf, ptr %idx)
  %matches = icmp eq i8 %expected, %chr
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

define void @zero.i1(ptr %winning, i64 %size) {
  %idx.ptr = alloca i64
  store i64 0, ptr %idx.ptr

  br label %loop_start

loop_start:
  %idx = load i64, ptr %idx.ptr
  call fastcc void @incr.i64(ptr %idx.ptr)
  %is_over_size = icmp eq i64 %idx, %size
  br i1 %is_over_size, label %loop_end, label %loop_cont

loop_cont:
  %elem = getelementptr i1, ptr %winning, i64 %idx
  store i1 0, ptr %elem

  br label %loop_start

loop_end:
  ret void
}

define void @zero.i64(ptr %winning, i64 %size) {
  %idx.ptr = alloca i64
  store i64 0, ptr %idx.ptr

  br label %loop_start

loop_start:
  %idx = load i64, ptr %idx.ptr
  call fastcc void @incr.i64(ptr %idx.ptr)
  %is_over_size = icmp eq i64 %idx, %size
  br i1 %is_over_size, label %loop_end, label %loop_cont

loop_cont:
  %elem = getelementptr i64, ptr %winning, i64 %idx
  store i64 0, ptr %elem

  br label %loop_start

loop_end:
  ret void
}

define void @double_or_init(ptr %val.ptr) {
  %val = load i64, ptr %val.ptr
  %is_zero = icmp eq i64 0, %val
  br i1 %is_zero, label %zero, label %non_zero

zero:
  store i64 1, ptr %val.ptr
  ret void

non_zero:
  %new_val = mul i64 2, %val
  store i64 %new_val, ptr %val.ptr
  ret void
}

define i64 @scratchcard_score(ptr %buf, ptr %idx) {
  call fastcc void @skip_to(ptr %buf, ptr %idx, i8 58)

  %winning_numbers.ptr = alloca [100 x i1]
  call fastcc void @zero.i1(ptr %winning_numbers.ptr, i64 100)

  %acc = alloca i64
  store i64 0, ptr %acc

  br label %winning_loop_start

winning_loop_start:
  call fastcc void @skip_spaces(ptr %buf, ptr %idx)
  %is_pipe = call fastcc i1 @char_eq(ptr %buf, ptr %idx, i8 124)
  br i1 %is_pipe, label %winning_loop_end, label %winning_loop_cont

winning_loop_cont:
  %number = call fastcc i64 @parse_i64(ptr %buf, ptr %idx)
  %winning_elem = getelementptr i1, ptr %winning_numbers.ptr, i64 %number
  store i1 1, ptr %winning_elem
  br label %winning_loop_start

winning_loop_end:
  call fastcc void @incr.i64(ptr %idx)
  br label %given_loop_start

given_loop_start:
  call fastcc void @skip_spaces(ptr %buf, ptr %idx)
  %is_newline = call fastcc i1 @char_eq(ptr %buf, ptr %idx, i8 10)
  br i1 %is_newline, label %given_loop_end, label %given_loop_cont

given_loop_cont:
  %given_number = call fastcc i64 @parse_i64(ptr %buf, ptr %idx)
  %given_elem = getelementptr i1, ptr %winning_numbers.ptr, i64 %given_number
  %is_winning = load i1, ptr %given_elem
  br i1 %is_winning, label %won, label %given_loop_start

won:
  call fastcc void @double_or_init(ptr %acc)
  br label %given_loop_start

given_loop_end:
  call fastcc void @incr.i64(ptr %idx)
  %final = load i64, ptr %acc
  ret i64 %final
}

define i64 @part_1(ptr %buf, i64 %buf_size) {
  %idx = alloca i64
  store i64 0, ptr %idx

  %acc = alloca i64
  store i64 0, ptr %acc

  br label %loop_start

loop_start:
  %is_eof = call fastcc i1 @char_eq(ptr %buf, ptr %idx, i8 0)
  br i1 %is_eof, label %loop_end, label %loop_cont

loop_cont:
  %idx.start = load i64, ptr %idx
  %scratchcard_value = call fastcc i64 @scratchcard_score(ptr %buf, ptr %idx)
  call fastcc void @add.i64(ptr %acc, i64 %scratchcard_value)
  br label %loop_start

loop_end:
  br label %quit

quit:
  %acc.final = load i64, ptr %acc
  ret i64 %acc.final
}

define i64 @scratchcard_winning(ptr %buf, ptr %idx) {
  call fastcc void @skip_to(ptr %buf, ptr %idx, i8 58)

  %winning_numbers.ptr = alloca [100 x i1]
  call fastcc void @zero.i1(ptr %winning_numbers.ptr, i64 100)

  %acc = alloca i64
  store i64 0, ptr %acc

  br label %winning_loop_start

winning_loop_start:
  call fastcc void @skip_spaces(ptr %buf, ptr %idx)
  %is_pipe = call fastcc i1 @char_eq(ptr %buf, ptr %idx, i8 124)
  br i1 %is_pipe, label %winning_loop_end, label %winning_loop_cont

winning_loop_cont:
  %number = call fastcc i64 @parse_i64(ptr %buf, ptr %idx)
  %winning_elem = getelementptr i1, ptr %winning_numbers.ptr, i64 %number
  store i1 1, ptr %winning_elem
  br label %winning_loop_start

winning_loop_end:
  call fastcc void @incr.i64(ptr %idx)
  br label %given_loop_start

given_loop_start:
  call fastcc void @skip_spaces(ptr %buf, ptr %idx)
  %is_newline = call fastcc i1 @char_eq(ptr %buf, ptr %idx, i8 10)
  br i1 %is_newline, label %given_loop_end, label %given_loop_cont

given_loop_cont:
  %given_number = call fastcc i64 @parse_i64(ptr %buf, ptr %idx)
  %given_elem = getelementptr i1, ptr %winning_numbers.ptr, i64 %given_number
  %is_winning = load i1, ptr %given_elem
  br i1 %is_winning, label %won, label %given_loop_start

won:
  call fastcc void @incr.i64(ptr %acc)
  br label %given_loop_start

given_loop_end:
  call fastcc void @incr.i64(ptr %idx)
  %final = load i64, ptr %acc
  ret i64 %final
}

define i64 @sum.i64(ptr %counters, i64 %size) {
  %idx.ptr = alloca i64
  store i64 0, ptr %idx.ptr

  %acc.ptr = alloca i64
  store i64 0, ptr %acc.ptr

  br label %loop_start

loop_start:
  %idx = load i64, ptr %idx.ptr
  call fastcc void @incr.i64(ptr %idx.ptr)
  %is_over_size = icmp eq i64 %idx, %size
  br i1 %is_over_size, label %loop_end, label %loop_cont

loop_cont:
  %elem.ptr = getelementptr i64, ptr %counters, i64 %idx
  %elem = load i64, ptr %elem.ptr
  call fastcc void @add.i64(ptr %acc.ptr, i64 %elem)
  br label %loop_start

loop_end:
  %acc = load i64, ptr %acc.ptr
  ret i64 %acc
}

define void @add_cards(ptr %counters, i64 %curr_idx, i64 %val, i64 %len) {
  %idx.ptr = alloca i64
  store i64 0, ptr %idx.ptr

  br label %loop_start

loop_start:
  %idx = load i64, ptr %idx.ptr
  call fastcc void @incr.i64(ptr %idx.ptr)
  %is_over_size = icmp eq i64 %idx, %len
  br i1 %is_over_size, label %loop_end, label %loop_cont

loop_cont:
  %elem_idx.0 = add i64 %idx, %curr_idx
  %elem_idx = add i64 %elem_idx.0, 1

  %elem.ptr = getelementptr i64, ptr %counters, i64 %elem_idx
  call fastcc void @add.i64(ptr %elem.ptr, i64 %val)

  br label %loop_start

loop_end:
  ret void
}

define i64 @part_2(ptr %buf, i64 %buf_size) {
  %idx = alloca i64
  store i64 0, ptr %idx

  %card_idx = alloca i64
  store i64 0, ptr %card_idx

  %counters = alloca [ 1024 x i64 ]
  call fastcc void @zero.i64(ptr %counters, i64 1024)

  br label %loop_start

loop_start:
  %is_eof = call fastcc i1 @char_eq(ptr %buf, ptr %idx, i8 0)
  br i1 %is_eof, label %loop_end, label %loop_cont

loop_cont:
  %idx.start = load i64, ptr %idx
  %scratchcard_count = call fastcc i64 @scratchcard_winning(ptr %buf, ptr %idx)

  %curr_card_idx = load i64, ptr %card_idx
  %curr_card_counter.ptr = getelementptr i64, ptr %counters, i64 %curr_card_idx
  call fastcc void @incr.i64(ptr %curr_card_counter.ptr)

  %curr_count = load i64, ptr %curr_card_counter.ptr
  call fastcc void @add_cards(ptr %counters, i64 %curr_card_idx, i64 %curr_count, i64 %scratchcard_count)

  call fastcc void @incr.i64(ptr %card_idx)
  br label %loop_start

loop_end:
  br label %quit

quit:
  %cards = call fastcc i64 @sum.i64(ptr %counters, i64 1024)
  ret i64 %cards
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

  %part_1_answer = call i64 @part_1(ptr %buf, i64 %read_bytes)
  call i32 @printf(ptr @str.print.part1, i64 %part_1_answer)

  %part_2_answer = call i64 @part_2(ptr %buf, i64 %read_bytes)
  call i32 @printf(ptr @str.print.part2, i64 %part_2_answer)

  ret i32 0
}
