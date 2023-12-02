;; TODO: refactor with arrays for colors
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

@str.red = private unnamed_addr constant [4 x i8] c"red\00", align 1
@str.green = private unnamed_addr constant [6 x i8] c"green\00", align 1
@str.blue = private unnamed_addr constant [5 x i8] c"blue\00", align 1

@i64.red = private unnamed_addr constant i64 1, align 1
@i64.green = private unnamed_addr constant i64 2, align 1
@i64.blue = private unnamed_addr constant i64 3, align 1

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

define i64 @decode_str_color(ptr %buf, ptr %idx) {
  %color_idx = load i64, ptr %idx, align 8
  %color_ptr = getelementptr i8, ptr %buf, i64 %color_idx

  %is_red = call i1 @has_prefix(ptr @str.red, ptr %color_ptr)
  br i1 %is_red, label %red, label %not_red

red:
  %idx_val_red = load i64, ptr %idx, align 8
  %idx_incremented_red = add i64 3, %idx_val_red
  store i64 %idx_incremented_red, ptr %idx, align 8

  %red_val = load i64, ptr @i64.red, align 8
  ret i64 %red_val

not_red:

  %is_green = call i1 @has_prefix(ptr @str.green, ptr %color_ptr)
  br i1 %is_green, label %green, label %not_green

green:
  %idx_val_green = load i64, ptr %idx, align 8
  %idx_incremented_green = add i64 5, %idx_val_green
  store i64 %idx_incremented_green, ptr %idx, align 8

  %green_val = load i64, ptr @i64.green, align 8
  ret i64 %green_val

not_green:

  %is_blue = call i1 @has_prefix(ptr @str.blue, ptr %color_ptr)
  br i1 %is_blue, label %blue, label %not_blue

blue:
  %idx_val_blue = load i64, ptr %idx, align 8
  %idx_incremented_blue = add i64 4, %idx_val_blue
  store i64 %idx_incremented_blue, ptr %idx, align 8

  %blue_val = load i64, ptr @i64.blue, align 8
  ret i64 %blue_val

not_blue:
  ret i64 0
}

define void @skip_to(ptr %buf, ptr %idx_ptr, i8 %target) {
  br label %loop_start
loop_start:
  %idx_val = load i64, ptr %idx_ptr, align 8
  %idx_incremented = add i64 1, %idx_val
  store i64 %idx_incremented, ptr %idx_ptr, align 8

  %buf_ptr = getelementptr i8, ptr %buf, i64 %idx_val
  %chr = load i8, ptr %buf_ptr, align 2

  %matches = icmp eq i8 %chr, %target
  br i1 %matches, label %quit, label %loop_start

quit:
  ret void
}

define i64 @parse_i64(ptr %buf, ptr %idx_ptr) {
  %acc = alloca i64, align 8
  store i64 0, ptr %acc, align 8

  br label %loop_start

loop_start:
  %idx_val = load i64, ptr %idx_ptr, align 8
  %buf_ptr = getelementptr i8, ptr %buf, i64 %idx_val
  %chr = load i8, ptr %buf_ptr, align 2

  %bounded_below = icmp ugt i8 %chr, 47
  %bounded_above = icmp ult i8 %chr, 58
  %in_range = and i1 %bounded_below, %bounded_above
  br i1 %in_range, label %is_digit, label %is_not_digit

is_digit:
  %idx_incremented = add i64 1, %idx_val
  store i64 %idx_incremented, ptr %idx_ptr, align 8

  %digit.i8 = sub i8 %chr, 48
  %digit = sext i8 %digit.i8 to i64

  %acc.0 = load i64, ptr %acc, align 8
  %acc.1 = mul i64 10, %acc.0
  %acc.2 = add i64 %digit, %acc.1
  store i64 %acc.2, ptr %acc, align 8

  br label %loop_start

is_not_digit:
  %acc.final = load i64, ptr %acc, align 8
  ret i64 %acc.final
}

define i1 @is_above_limit(i64 %num, i64 %color) {
  %red_const = load i64, ptr @i64.red
  %is_red = icmp eq i64 %color, %red_const
  br i1 %is_red, label %red, label %not_red

red:
  %is_above_red = icmp sgt i64 %num, 12
  ret i1 %is_above_red

not_red:

  %green_const = load i64, ptr @i64.green
  %is_green = icmp eq i64 %color, %green_const
  br i1 %is_green, label %green, label %not_green

green:
  %is_above_green = icmp sgt i64 %num, 13
  ret i1 %is_above_green

not_green:

  %blue_const = load i64, ptr @i64.blue
  %is_blue = icmp eq i64 %color, %blue_const
  br i1 %is_blue, label %blue, label %not_blue

blue:
  %is_above_blue = icmp sgt i64 %num, 14
  ret i1 %is_above_blue

not_blue:
  ret i1 0 ;; ERROR
}

define i1 @char_eq(ptr %buf, ptr %idx, i8 %expected) {
  %idx_val = load i64, ptr %idx, align 8
  %chr_ptr = getelementptr i8, ptr %buf, i64 %idx_val
  %chr = load i8, ptr %chr_ptr, align 2
  %matches = icmp eq i8 %expected, %chr
  br i1 %matches, label %true, label %false

false:
  ret i1 0

true:
  ret i1 1
}

define void @incr(ptr %val) {
  %prev = load i64, ptr %val, align 8
  %incremented = add i64 1, %prev
  store i64 %incremented, ptr %val, align 8
  ret void
}

define void @add.i64(ptr %dest, ptr %op) {
  %val = load i64, ptr %dest
  %op.val = load i64, ptr %op

  %incremented = add i64 %op.val, %val
  store i64 %incremented, ptr %dest, align 8
  ret void
}

define i64 @part_1(ptr %buf) {
  %stderr = load ptr, ptr @stderr, align 8

  %first_digit = alloca i64, align 8
  store i64 0, ptr %first_digit, align 8

  %total_sum = alloca i64, align 8
  store i64 0, ptr %total_sum, align 8

  %idx = alloca i64, align 8
  store i64 0, ptr %idx, align 8

  %game_id_ptr = alloca i64, align 8
  store i64 1, ptr %game_id_ptr, align 8

  br label %loop_start

loop_start:
  %eof = call i1 @char_eq(ptr %buf, ptr %idx, i8 0)
  br i1 %eof, label %quit, label %not_eof

not_eof:
  call void @skip_to(ptr %buf, ptr %idx, i8 32) ; strip 'Game'
  call void @skip_to(ptr %buf, ptr %idx, i8 32) ; strip game id
  br label %line_loop_start

line_loop_start:
  %num = call i64 @parse_i64(ptr %buf, ptr %idx)
  call void @skip_to(ptr %buf, ptr %idx, i8 32)
  %color = call i64 @decode_str_color(ptr %buf, ptr %idx)
  %is_newline = call i1 @char_eq(ptr %buf, ptr %idx, i8 10)

  %is_over_limit = call i1 @is_above_limit(i64 %num, i64 %color)

  br i1 %is_over_limit, label %over_limit, label %not_over_limit

not_over_limit:
  br i1 %is_newline, label %newline, label %not_newline

over_limit:
  call void @skip_to(ptr %buf, ptr %idx, i8 10)

  %tmp = load i64, ptr %game_id_ptr
  call void @incr(ptr %game_id_ptr)
  br label %loop_start

newline:
  %game_id = load i64, ptr %game_id_ptr
  call void @add.i64(ptr %total_sum, ptr %game_id_ptr)
  call void @incr(ptr %game_id_ptr)
  call void @incr(ptr %idx)
  br label %loop_start

not_newline:
  call void @skip_to(ptr %buf, ptr %idx, i8 32)
  br label %line_loop_start

quit:
  %total_sum.final = load i64, ptr %total_sum, align 8
  ret i64 %total_sum.final
}

define void @update_maximum(i64 %num, ptr %max) {
  %prev = load i64, ptr %max
  %should_update = icmp sgt i64 %num, %prev
  br i1 %should_update, label %update, label %no_update

update:
  store i64 %num, ptr %max
  ret void

no_update:
  ret void
}

define void @update_maximums(i64 %num, i64 %color, ptr %max_red_ptr, ptr %max_green_ptr, ptr %max_blue_ptr) {
  %red_const = load i64, ptr @i64.red
  %is_red = icmp eq i64 %color, %red_const
  br i1 %is_red, label %red, label %not_red

red:
  call void @update_maximum(i64 %num, ptr %max_red_ptr)
  ret void

not_red:

  %green_const = load i64, ptr @i64.green
  %is_green = icmp eq i64 %color, %green_const
  br i1 %is_green, label %green, label %not_green

green:
  call void @update_maximum(i64 %num, ptr %max_green_ptr)
  ret void

not_green:

  %blue_const = load i64, ptr @i64.blue
  %is_blue = icmp eq i64 %color, %blue_const
  br i1 %is_blue, label %blue, label %not_blue

blue:
  call void @update_maximum(i64 %num, ptr %max_blue_ptr)
  ret void

not_blue:
  ret void ;; ERROR
}

define i64 @part_2(ptr %buf) {
  %stderr = load ptr, ptr @stderr, align 8

  %first_digit = alloca i64, align 8
  store i64 0, ptr %first_digit, align 8

  %total_sum = alloca i64, align 8
  store i64 0, ptr %total_sum, align 8

  %idx = alloca i64, align 8
  store i64 0, ptr %idx, align 8

  %max_red_ptr = alloca i64, align 8
  store i64 0, ptr %max_red_ptr, align 8

  %max_green_ptr = alloca i64, align 8
  store i64 0, ptr %max_green_ptr, align 8

  %max_blue_ptr = alloca i64, align 8
  store i64 0, ptr %max_blue_ptr, align 8

  br label %loop_start

loop_start:
  %eof = call i1 @char_eq(ptr %buf, ptr %idx, i8 0)
  br i1 %eof, label %quit, label %not_eof

not_eof:
  call void @skip_to(ptr %buf, ptr %idx, i8 32) ; strip 'Game'
  call void @skip_to(ptr %buf, ptr %idx, i8 32) ; strip game id
  br label %line_loop_start

line_loop_start:
  %num = call i64 @parse_i64(ptr %buf, ptr %idx)
  call void @skip_to(ptr %buf, ptr %idx, i8 32)
  %color = call i64 @decode_str_color(ptr %buf, ptr %idx)
  %is_newline = call i1 @char_eq(ptr %buf, ptr %idx, i8 10)

  call void @update_maximums(i64 %num, i64 %color, ptr %max_red_ptr, ptr %max_green_ptr, ptr %max_blue_ptr)

  br i1 %is_newline, label %newline, label %not_newline

newline:
  %max_red = load i64, ptr %max_red_ptr
  %max_green = load i64, ptr %max_green_ptr
  %max_blue = load i64, ptr %max_blue_ptr
  %power.0 = mul i64 %max_red, %max_green
  %power = mul i64 %max_blue, %power.0

  %total_sum.prev = load i64, ptr %total_sum
  %total_sum.added = add i64 %total_sum.prev, %power
  store i64 %total_sum.added, ptr %total_sum

  store i64 0, ptr %max_red_ptr, align 8
  store i64 0, ptr %max_green_ptr, align 8
  store i64 0, ptr %max_blue_ptr, align 8

  call void @incr(ptr %idx)
  br label %loop_start

not_newline:
  call void @skip_to(ptr %buf, ptr %idx, i8 32)
  br label %line_loop_start

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
