declare ptr @fopen(ptr noundef, ptr noundef) #1
declare i64 @fread(ptr noundef, i64 noundef, i64 noundef, ptr noundef) #1
declare i32 @fputs(ptr nocapture noundef readonly, ptr nocapture noundef) local_unnamed_addr #1
declare i32 @printf(ptr noundef, ...) #1

@stdout = external local_unnamed_addr constant ptr, align 8
@stderr = external local_unnamed_addr constant ptr, align 8

@str.usage = private unnamed_addr constant [8 x i8] c"Usage: \00", align 1
@str.files = private unnamed_addr constant [9 x i8] c" <file>\0A\00", align 1
@str.read_mode = private unnamed_addr constant [2 x i8] c"r\00", align 1
@str.err_could_not_open = private unnamed_addr constant [27 x i8] c"Could not open input file\0A\00", align 1
@str.err_buffer_too_small = private unnamed_addr constant [34 x i8] c"Could not fit file in the buffer\0A\00", align 1
@str.print.part1 = private unnamed_addr constant [14 x i8] c"part 1: %llu\0A\00", align 1
@str.print.part2 = private unnamed_addr constant [14 x i8] c"part 2: %llu\0A\00", align 1

@str.one = private unnamed_addr constant [4 x i8] c"one\00", align 1
@str.two = private unnamed_addr constant [4 x i8] c"two\00", align 1
@str.three = private unnamed_addr constant [6 x i8] c"three\00", align 1
@str.four = private unnamed_addr constant [5 x i8] c"four\00", align 1
@str.five = private unnamed_addr constant [5 x i8] c"five\00", align 1
@str.six = private unnamed_addr constant [4 x i8] c"six\00", align 1
@str.seven = private unnamed_addr constant [6 x i8] c"seven\00", align 1
@str.eight = private unnamed_addr constant [6 x i8] c"eight\00", align 1
@str.nine = private unnamed_addr constant [5 x i8] c"nine\00", align 1

define i1 @has_prefix(ptr %prefix, ptr %input) {
  %idx = alloca i64, align 8
  store i64 0, ptr %idx, align 8
  br label %loop_start

loop_start:
  %idx_val = load i64, ptr %idx, align 8
  %idx_incremented = add i64 1, %idx_val
  store i64 %idx_incremented, ptr %idx, align 8

  %prefix_chr_ptr = getelementptr i8, ptr %prefix, i64 %idx_val
  %prefix_chr = load i8, ptr %prefix_chr_ptr, align 2
  %prefix_eof = icmp eq i8 %prefix_chr, 0
  br i1 %prefix_eof, label %true, label %continue.0

continue.0:
  %input_chr_ptr = getelementptr i8, ptr %input, i64 %idx_val
  %input_chr = load i8, ptr %input_chr_ptr, align 2
  %input_eof = icmp eq i8 %input_chr, 0
  br i1 %input_eof, label %false, label %continue.1

continue.1:
  %chars_eq = icmp eq i8 %prefix_chr, %input_chr
  br i1 %chars_eq, label %loop_start, label %false

true:
  ret i1 1

false:
  ret i1 0
}

define void @finish_line(ptr %total_sum, ptr %first_digit, ptr %last_digit) {
  %line_sum.first.0 = load i64, ptr %first_digit, align 8
  %line_sum.first = sub i64 %line_sum.first.0, 48

  %line_sum.last.0 = load i64, ptr %last_digit, align 8
  %line_sum.last = sub i64 %line_sum.last.0, 48

  %line_sum.0 = add i64 %line_sum.first, 0
  %line_sum.1 = mul i64 %line_sum.0, 10
  %line_sum = add i64 %line_sum.1, %line_sum.last

  %total_sum.current = load i64, ptr %total_sum, align 8
  %total_sum.added = add i64 %total_sum.current, %line_sum
  store i64 %total_sum.added, ptr %total_sum, align 8

  store i64 0, ptr %first_digit, align 8
  store i64 0, ptr %last_digit, align 8

  ret void
}

define void @set_first_last(i64 %digit, ptr %first_digit, ptr %last_digit) {
  store i64 %digit, ptr %last_digit, align 8

  %current_first = load i64, ptr %first_digit
  %is_first_set = icmp ne i64 %current_first, 0
  br i1 %is_first_set, label %quit, label %set_first_digit

set_first_digit:
  store i64 %digit, ptr %first_digit, align 8
  br label %quit

quit:
  ret void
}

define i64 @decode_str_digit(ptr %chr_ptr) {
  %is_one = call i1 @has_prefix(ptr @str.one, ptr %chr_ptr)
  br i1 %is_one, label %one, label %not_one

one:
  ret i64 49

not_one:
  %is_two = call i1 @has_prefix(ptr @str.two, ptr %chr_ptr)
  br i1 %is_two, label %two, label %not_two

two:
  ret i64 50

not_two:
  %is_three = call i1 @has_prefix(ptr @str.three, ptr %chr_ptr)
  br i1 %is_three, label %three, label %not_three

three:
  ret i64 51

not_three:
  %is_four = call i1 @has_prefix(ptr @str.four, ptr %chr_ptr)
  br i1 %is_four, label %four, label %not_four

four:
  ret i64 52

not_four:
  %is_five = call i1 @has_prefix(ptr @str.five, ptr %chr_ptr)
  br i1 %is_five, label %five, label %not_five

five:
  ret i64 53

not_five:
  %is_six = call i1 @has_prefix(ptr @str.six, ptr %chr_ptr)
  br i1 %is_six, label %six, label %not_six

six:
  ret i64 54

not_six:
  %is_seven = call i1 @has_prefix(ptr @str.seven, ptr %chr_ptr)
  br i1 %is_seven, label %seven, label %not_seven

seven:
  ret i64 55

not_seven:
  %is_eight = call i1 @has_prefix(ptr @str.eight, ptr %chr_ptr)
  br i1 %is_eight, label %eight, label %not_eight

eight:
  ret i64 56

not_eight:
  %is_nine = call i1 @has_prefix(ptr @str.nine, ptr %chr_ptr)
  br i1 %is_nine, label %nine, label %not_nine

nine:
  ret i64 57

not_nine:
  ret i64 0
}

define i64 @part_1(ptr %buf) {
  %first_digit = alloca i64, align 8
  store i64 0, ptr %first_digit, align 8

  %last_digit = alloca i64, align 8
  store i64 0, ptr %last_digit, align 8

  %total_sum = alloca i64, align 8
  store i64 0, ptr %total_sum, align 8

  %idx = alloca i64, align 8
  store i64 0, ptr %idx, align 8

  br label %loop_start

loop_start:
  %idx_val = load i64, ptr %idx, align 8
  %idx_incremented = add i64 1, %idx_val
  store i64 %idx_incremented, ptr %idx, align 8

  %chr_ptr = getelementptr i8, ptr %buf, i64 %idx_val
  %chr = load i8, ptr %chr_ptr, align 2

  %eof = icmp eq i8 0, %chr
  br i1 %eof, label %quit, label %not_eof

not_eof:
  %is_newline = icmp eq i8 10, %chr
  br i1 %is_newline, label %newline, label %not_newline

newline:
  call void @finish_line(ptr %total_sum, ptr %first_digit, ptr %last_digit)
  br label %loop_start

not_newline:
  %bounded_below = icmp ugt i8 %chr, 48
  %bounded_above = icmp ult i8 %chr, 58
  %in_range = and i1 %bounded_below, %bounded_above
  br i1 %in_range, label %is_digit, label %loop_start

is_digit:
  %digit = sext i8 %chr to i64
  call void @set_first_last(i64 %digit, ptr %first_digit, ptr %last_digit)
  br label %loop_start

quit:
  %total_sum.final = load i64, ptr %total_sum, align 8
  ret i64 %total_sum.final
}

define i64 @part_2(ptr %buf) {
  %first_digit = alloca i64, align 8
  store i64 0, ptr %first_digit, align 8

  %last_digit = alloca i64, align 8
  store i64 0, ptr %last_digit, align 8

  %total_sum = alloca i64, align 8
  store i64 0, ptr %total_sum, align 8

  %idx = alloca i64, align 8
  store i64 0, ptr %idx, align 8

  br label %loop_start

loop_start:
  %idx_val = load i64, ptr %idx, align 8
  %idx_incremented = add i64 1, %idx_val
  store i64 %idx_incremented, ptr %idx, align 8

  %chr_ptr = getelementptr i8, ptr %buf, i64 %idx_val
  %chr = load i8, ptr %chr_ptr, align 2

  %eof = icmp eq i8 0, %chr
  br i1 %eof, label %quit, label %not_eof

not_eof:
  %is_newline = icmp eq i8 10, %chr
  br i1 %is_newline, label %newline, label %not_newline

newline:
  call void @finish_line(ptr %total_sum, ptr %first_digit, ptr %last_digit)
  br label %loop_start

not_newline:
  %is_below_digits = icmp ult i8 %chr, 48
  br i1 %is_below_digits, label %not_digit, label %not_below_digits

not_below_digits:
  %is_above_digits = icmp ugt i8 %chr, 57
  br i1 %is_above_digits, label %not_digit, label %is_digit

is_digit:
  %digit = sext i8 %chr to i64
  call void @set_first_last(i64 %digit, ptr %first_digit, ptr %last_digit)
  br label %loop_start

not_digit:
  %decoded_from_str = call i64 @decode_str_digit(ptr %chr_ptr)
  %decoding_failure = icmp eq i64 %decoded_from_str, 0
  br i1 %decoding_failure, label %loop_start, label %set_not_digit

set_not_digit:
  call void @set_first_last(i64 %decoded_from_str, ptr %first_digit, ptr %last_digit)
  br label %loop_start

quit:
  %total_sum.final = load i64, ptr %total_sum, align 8
  ret i64 %total_sum.final
}

define i32 @main(i32 %argc, ptr %argv) local_unnamed_addr #0 {
  %stderr = load ptr, ptr @stderr, align 8
  %stdout = load ptr, ptr @stdout, align 8

  %prog_name_ptr = getelementptr ptr, ptr %argv, i64 0
  %prog_name = load ptr, ptr %prog_name_ptr, align 8

  %correct_usage = icmp eq i32 2, %argc
  br i1 %correct_usage, label %file_provided, label %show_usage

show_usage:
  call i32 @fputs(ptr @str.usage, ptr %stderr)
  call i32 @fputs(ptr %prog_name, ptr %stderr)
  call i32 @fputs(ptr @str.files, ptr %stderr)
  ret i32 1

file_provided:
  %fp_ptr = getelementptr ptr, ptr %argv, i64 1
  %fp = load ptr, ptr %fp_ptr, align 8
  %fd = call ptr @fopen(ptr %fp, ptr @str.read_mode)
  %opend_correctly = icmp ne ptr %fd, null
  br i1 %opend_correctly, label %read_file, label %invalid_file

invalid_file:
  call i32 @fputs(ptr @str.err_could_not_open, ptr %stderr)
  ret i32 1

read_file:
  %buf = alloca [65536 x i8], align 16
  %read_bytes = call i64 @fread(ptr %buf, i64 1, i64 65535, ptr %fd)
  %read_everything = icmp eq i64 65535, %read_bytes
  br i1 %read_everything, label %buffer_too_small, label %process_file

buffer_too_small:
  call i32 @fputs(ptr @str.err_buffer_too_small, ptr %stderr)
  ret i32 1

process_file:
  %last_char = getelementptr i8, ptr %buf, i64 %read_bytes
  store i8 0, ptr %last_char, align 8

  %part_1_answer = call i64 @part_1(ptr %buf)
  call i32 @printf(ptr @str.print.part1, i64 %part_1_answer)

  %part_2_answer = call i64 @part_2(ptr %buf)
  call i32 @printf(ptr @str.print.part2, i64 %part_2_answer)

  ret i32 0
}
