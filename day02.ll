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

define i64 @parse_color(ptr %buf, ptr %idx) {
  %color_idx = load i64, ptr %idx
  %color_ptr = getelementptr i8, ptr %buf, i64 %color_idx
  %chr = load i8, ptr %color_ptr

  switch i8 %chr, label %otherwise
    [ i8 114, label %red
      i8 103, label %green
      i8 98, label %blue
    ]
  
red:
  %idx.red = add i64 %color_idx, 3
  store i64 %idx.red, ptr %idx
  ret i64 1

green:
  %idx.green = add i64 %color_idx, 5
  store i64 %idx.green, ptr %idx
  ret i64 2

blue:
  %idx.blue = add i64 %color_idx, 4
  store i64 %idx.blue, ptr %idx
  ret i64 3

otherwise:
  ret i64 0
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

define i1 @char_eq(ptr %buf, ptr %idx, i8 %expected) {
  %idx_val = load i64, ptr %idx, align 8
  %chr_ptr = getelementptr i8, ptr %buf, i64 %idx_val
  %chr = load i8, ptr %chr_ptr, align 2
  %matches = icmp eq i8 %expected, %chr
  ret i1 %matches
}

define void @incr(ptr %val) {
  %prev = load i64, ptr %val, align 8
  %incremented = add i64 1, %prev
  store i64 %incremented, ptr %val, align 8
  ret void
}

define void @add.i64(ptr %dest, i64 %op) {
  %val = load i64, ptr %dest
  %incremented = add i64 %op, %val
  store i64 %incremented, ptr %dest, align 8
  ret void
}

define void @add.i64.ptr(ptr %dest, ptr %op) {
  %val = load i64, ptr %dest
  %op.val = load i64, ptr %op

  %incremented = add i64 %op.val, %val
  store i64 %incremented, ptr %dest, align 8
  ret void
}

define i64 @part_1(ptr %buf) {
  %stderr = load ptr, ptr @stderr, align 8

  %total_sum = alloca i64, align 8
  store i64 0, ptr %total_sum, align 8

  %idx = alloca i64, align 8
  store i64 0, ptr %idx, align 8

  br label %loop_start

loop_start:
  %eof = call fastcc i1 @char_eq(ptr %buf, ptr %idx, i8 0)
  br i1 %eof, label %quit, label %not_eof

not_eof:
  call fastcc void @skip_to(ptr %buf, ptr %idx, i8 32) ; strip 'Game'
  %game_id = call fastcc i64 @parse_i64(ptr %buf, ptr %idx)
  call fastcc void @add.i64(ptr %idx, i64 2)
  br label %line_loop_start

line_loop_start:
  %num = call fastcc i64 @parse_i64(ptr %buf, ptr %idx)
  call fastcc void @skip_to(ptr %buf, ptr %idx, i8 32)
  %color = call fastcc i64 @parse_color(ptr %buf, ptr %idx)
  %is_newline = call fastcc i1 @char_eq(ptr %buf, ptr %idx, i8 10)

  %limit = add i64 %color, 11
  %is_over_limit = icmp sgt i64 %num, %limit

  br i1 %is_over_limit, label %over_limit, label %not_over_limit

not_over_limit:
  br i1 %is_newline, label %newline, label %not_newline

over_limit:
  call fastcc void @skip_to(ptr %buf, ptr %idx, i8 10)

  br label %loop_start

newline:
  call fastcc void @add.i64(ptr %total_sum, i64 %game_id)
  call fastcc void @incr(ptr %idx)
  br label %loop_start

not_newline:
  call fastcc void @skip_to(ptr %buf, ptr %idx, i8 32)
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
  switch i64 %color, label %otherwise
    [ i64 1, label %red
      i64 2, label %green
      i64 3, label %blue
    ]

red:
  call fastcc void @update_maximum(i64 %num, ptr %max_red_ptr)
  ret void

green:
  call fastcc void @update_maximum(i64 %num, ptr %max_green_ptr)
  ret void

blue:
  call fastcc void @update_maximum(i64 %num, ptr %max_blue_ptr)
  ret void

otherwise:
  ret void
}

define i64 @part_2(ptr %buf) {
  %stderr = load ptr, ptr @stderr, align 8

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
  %eof = call fastcc i1 @char_eq(ptr %buf, ptr %idx, i8 0)
  br i1 %eof, label %quit, label %not_eof

not_eof:
  call fastcc void @skip_to(ptr %buf, ptr %idx, i8 32) ; strip 'Game'
  call fastcc void @skip_to(ptr %buf, ptr %idx, i8 32) ; strip game id
  br label %line_loop_start

line_loop_start:
  %num = call fastcc i64 @parse_i64(ptr %buf, ptr %idx)
  call fastcc void @skip_to(ptr %buf, ptr %idx, i8 32)
  %color = call fastcc i64 @parse_color(ptr %buf, ptr %idx)
  %is_newline = call fastcc i1 @char_eq(ptr %buf, ptr %idx, i8 10)

  call fastcc void @update_maximums(i64 %num, i64 %color, ptr %max_red_ptr, ptr %max_green_ptr, ptr %max_blue_ptr)

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

  call fastcc void @incr(ptr %idx)
  br label %loop_start

not_newline:
  call fastcc void @skip_to(ptr %buf, ptr %idx, i8 32)
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

  %part_1_answer = call fastcc i64 @part_1(ptr %buf)
  call i32 @printf(ptr @str.print.part1, i64 %part_1_answer)

  %part_2_answer = call fastcc i64 @part_2(ptr %buf)
  call i32 @printf(ptr @str.print.part2, i64 %part_2_answer)

  ret i32 0
}
