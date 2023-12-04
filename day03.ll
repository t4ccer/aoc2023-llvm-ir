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

define i64 @get_width(ptr %buf) {
  %idx = alloca i64
  store i64 0, ptr %idx

  %width = alloca i64
  store i64 0, ptr %width

  br label %loop_start

loop_start:
  %is_newline = call fastcc i1 @char_eq(ptr %buf, ptr %idx, i8 10)
  br i1 %is_newline, label %loop_exit, label %not_newline

not_newline:
  call fastcc void @incr.i64(ptr %width)
  call fastcc void @incr.i64(ptr %idx)
  br label %loop_start

loop_exit:
  %width.final.0 = load i64, ptr %width
  %width.final = add i64 1, %width.final.0
  ret i64 %width.final
}

define i64 @clamp(i64 %value, i64 %low, i64 %high) {
  %is_below = icmp slt i64 %value, %low
  br i1 %is_below, label %below, label %not_below

below:
  ret i64 %low

not_below:
  %is_above = icmp sgt i64 %value, %high
  br i1 %is_above, label %above, label %not_above

above:
  ret i64 %high

not_above:
  ret i64 %value
}

define i1 @is_symbol(i8 %chr) {
  %is_digit = call fastcc i1 @is_digit(i8 %chr)
  %is_dot = icmp eq i8 %chr, 46

  %is_not_symbol = or i1 %is_digit, %is_dot

  br i1 %is_not_symbol, label %false, label %true

false:
  ret i1 false

true:
  ret i1 true
}

define i1 @is_near_symbol(i64 %idx.start, i64 %idx.end, i64 %width, i64 %height.0, ptr %buf) {
  %height = sub i64 %height.0, 1
  %width.sub = sub i64 %width, 2

  %x.start.on = srem i64 %idx.start, %width
  %x.start.below = sub i64 %x.start.on, 1
  %x.start = call fastcc i64 @clamp(i64 %x.start.below, i64 0, i64 %width.sub)

  %len = sub i64 %idx.end, %idx.start
  %x.end.0 = add i64 %x.start.below, %len
  %x.end.1 = add i64 1, %x.end.0
  %x.end = call fastcc i64 @clamp(i64 %x.end.1, i64 0, i64 %width.sub)

  %y.start.on = sdiv i64 %idx.start, %width
  %y.start.above = sub i64 %y.start.on, 1
  %y.start = call fastcc i64 @clamp(i64 %y.start.above, i64 0, i64 %height)

  %y.end.below = add i64 %y.start.on, 1
  %y.end = call fastcc i64 @clamp(i64 %y.end.below, i64 0, i64 %height)

  %x.ptr = alloca i64
  store i64 %x.start, ptr %x.ptr

  %y.ptr = alloca i64
  store i64 %y.start, ptr %y.ptr

  br label %y_loop_start

y_loop_start:
  store i64 %x.start, ptr %x.ptr
  %y = load i64, ptr %y.ptr
  %is_over_y = icmp sgt i64 %y, %y.end
  br i1 %is_over_y, label %false, label %x_loop_start

x_loop_start:
  %x = load i64, ptr %x.ptr
  %is_over_x = icmp sgt i64 %x, %x.end
  br i1 %is_over_x, label %y_loop_end, label %x_loop_cont

x_loop_cont:
  %idx.0 = mul i64 %y, %width
  %idx = add i64 %idx.0, %x
  %chr_ptr = getelementptr i8, ptr %buf, i64 %idx
  %chr = load i8, ptr %chr_ptr

  %is_symbol = call fastcc i1 @is_symbol(i8 %chr)
  br i1 %is_symbol, label %true, label %x_loop_end

x_loop_end:
  call fastcc void @incr.i64(ptr %x.ptr)
  br label %x_loop_start

y_loop_end:
  call fastcc void @incr.i64(ptr %y.ptr)
  br label %y_loop_start

true:
  ret i1 true

false:
  ret i1 false
}

define i64 @part_1(ptr %buf, i64 %buf_size) {
  %width = call fastcc i64 @get_width(ptr %buf)
  %height = sdiv i64 %buf_size, %width

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
  %number = call fastcc i64 @parse_i64(ptr %buf, ptr %idx)
  %number_parse_error = icmp eq i64 %number, 0
  br i1 %number_parse_error, label %invalid_number, label %valid_number

invalid_number:
  call fastcc void @incr.i64(ptr %idx)
  br label %loop_start

valid_number:
  %idx.end = load i64, ptr %idx
  %is_near_symbol = call fastcc i1 @is_near_symbol(i64 %idx.start, i64 %idx.end, i64 %width, i64 %height, ptr %buf)
  br i1 %is_near_symbol, label %near_symbol, label %loop_start

near_symbol:
  call fastcc void @add.i64(ptr %acc, i64 %number)
  br label %loop_start

loop_end:
  br label %quit

quit:
  %acc.final = load i64, ptr %acc
  ret i64 %acc.final
}

define void @reset_gears(ptr %gears, i64 %size) {
  %idx.ptr = alloca i64
  store i64 0, ptr %idx.ptr

  br label %loop_start

loop_start:
  %idx = load i64, ptr %idx.ptr
  call fastcc void @incr.i64(ptr %idx.ptr)
  %is_over_size = icmp eq i64 %idx, %size
  br i1 %is_over_size, label %loop_end, label %loop_cont

loop_cont:
  %gear = getelementptr %struct.gear, ptr %gears, i64 %idx
  %gear.0.ptr = getelementptr %struct.gear, ptr %gear, i32 0, i32 0
  store i64 0, ptr %gear.0.ptr

  %gear.1.ptr = getelementptr %struct.gear, ptr %gear, i32 0, i32 1
  store i64 0, ptr %gear.1.ptr

  %gear.2.ptr = getelementptr %struct.gear, ptr %gear, i32 0, i32 2
  store i64 0, ptr %gear.2.ptr

  br label %loop_start

loop_end:
  ret void
}

define void @mark_gear_at(i64 %idx, ptr %gears, i64 %number) {
  %gear = getelementptr %struct.gear, ptr %gears, i64 %idx
  %gear.0.ptr = getelementptr %struct.gear, ptr %gear, i64 0
  %gear_num = load i64, ptr %gear.0.ptr
  call fastcc void @incr.i64(ptr %gear.0.ptr)

  %gear.1.ptr = getelementptr %struct.gear, ptr %gear, i64 1
  %gear.2.ptr = getelementptr %struct.gear, ptr %gear, i64 2

  %is_first_empty = icmp eq i64 %gear_num, 0
  br i1 %is_first_empty, label %first_empty, label %first_non_empty

first_empty:
  store i64 %number, ptr %gear.1.ptr
  ret void

first_non_empty:
  %is_second_empty = icmp eq i64 %gear_num, 1
  br i1 %is_second_empty, label %second_empty, label %second_non_empty

second_empty:
  store i64 %number, ptr %gear.2.ptr
  ret void

second_non_empty:
  ret void
}

define void @mark_gear(i64 %idx.start, i64 %idx.end, i64 %width, i64 %height.0, ptr %buf, ptr %gears, i64 %number) {
  %height = sub i64 %height.0, 1
  %width.sub = sub i64 %width, 2

  %x.start.on = srem i64 %idx.start, %width
  %x.start.below = sub i64 %x.start.on, 1
  %x.start = call fastcc i64 @clamp(i64 %x.start.below, i64 0, i64 %width.sub)

  %len = sub i64 %idx.end, %idx.start
  %x.end.0 = add i64 %x.start.below, %len
  %x.end.1 = add i64 1, %x.end.0
  %x.end = call fastcc i64 @clamp(i64 %x.end.1, i64 0, i64 %width.sub)

  %y.start.on = sdiv i64 %idx.start, %width
  %y.start.above = sub i64 %y.start.on, 1
  %y.start = call fastcc i64 @clamp(i64 %y.start.above, i64 0, i64 %height)

  %y.end.below = add i64 %y.start.on, 1
  %y.end = call fastcc i64 @clamp(i64 %y.end.below, i64 0, i64 %height)

  %x.ptr = alloca i64
  store i64 %x.start, ptr %x.ptr

  %y.ptr = alloca i64
  store i64 %y.start, ptr %y.ptr

  br label %y_loop_start

y_loop_start:
  store i64 %x.start, ptr %x.ptr
  %y = load i64, ptr %y.ptr
  %is_over_y = icmp sgt i64 %y, %y.end
  br i1 %is_over_y, label %quit, label %x_loop_start

x_loop_start:
  %x = load i64, ptr %x.ptr
  %is_over_x = icmp sgt i64 %x, %x.end
  br i1 %is_over_x, label %y_loop_end, label %x_loop_cont

x_loop_cont:
  %idx.0 = mul i64 %y, %width
  %idx = add i64 %idx.0, %x
  %chr_ptr = getelementptr i8, ptr %buf, i64 %idx
  %chr = load i8, ptr %chr_ptr

  %is_star = icmp eq i8 %chr, 42
  br i1 %is_star, label %star, label %no_star

star:
  call fastcc void @mark_gear_at(i64 %idx, ptr %gears, i64 %number)
  br label %x_loop_end

no_star:
  br label %x_loop_end

x_loop_end:
  call fastcc void @incr.i64(ptr %x.ptr)
  br label %x_loop_start

y_loop_end:
  call fastcc void @incr.i64(ptr %y.ptr)
  br label %y_loop_start

quit:
  ret void
}

define i64 @count_gears(ptr %gears, i64 %size) {
  %acc = alloca i64
  store i64 0, ptr %acc

  %idx.ptr = alloca i64
  store i64 0, ptr %idx.ptr

  br label %loop_start

loop_start:
  %idx = load i64, ptr %idx.ptr
  call fastcc void @incr.i64(ptr %idx.ptr)
  %is_over_size = icmp eq i64 %idx, %size
  br i1 %is_over_size, label %quit, label %loop_cont

loop_cont:
  %gear = getelementptr %struct.gear, ptr %gears, i64 %idx
  %gear.num.ptr = getelementptr %struct.gear, ptr %gear, i64 0
  %gear.num = load i64, ptr %gear.num.ptr

  %gear.1.ptr = getelementptr %struct.gear, ptr %gear, i64 1
  %gear.2.ptr = getelementptr %struct.gear, ptr %gear, i64 2

  %gear.1 = load i64, ptr %gear.1.ptr
  %gear.2 = load i64, ptr %gear.2.ptr

  %is_two = icmp eq i64 %gear.num, 2
  br i1 %is_two, label %two, label %skip

two:
  %gear_prod = mul i64 %gear.1, %gear.2

  call fastcc void @add.i64(ptr %acc, i64 %gear_prod)
  br label %loop_start

skip:
  br label %loop_start

quit:
  %acc.final = load i64, ptr %acc
  ret i64 %acc.final
}

define i64 @part_2(ptr %buf, i64 %buf_size) {
  %width = call fastcc i64 @get_width(ptr %buf)
  %height = sdiv i64 %buf_size, %width

  %gears = alloca [ 65536 x %struct.gear]
  call fastcc void @reset_gears(ptr %gears, i64 65536)

  %idx = alloca i64
  store i64 0, ptr %idx

  br label %loop_start

loop_start:
  %is_eof = call fastcc i1 @char_eq(ptr %buf, ptr %idx, i8 0)
  br i1 %is_eof, label %loop_end, label %loop_cont

loop_cont:
  %idx.start = load i64, ptr %idx
  %number = call fastcc i64 @parse_i64(ptr %buf, ptr %idx)
  %number_parse_error = icmp eq i64 %number, 0
  br i1 %number_parse_error, label %invalid_number, label %valid_number

invalid_number:
  call fastcc void @incr.i64(ptr %idx)
  br label %loop_start

valid_number:
  %idx.end = load i64, ptr %idx
  call fastcc void @mark_gear(i64 %idx.start, i64 %idx.end, i64 %width, i64 %height, ptr %buf, ptr %gears, i64 %number)
  br label %loop_start

loop_end:
  br label %quit

quit:
  %ans = call fastcc i64 @count_gears(ptr %gears, i64 65536)
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

  %part_1_answer = call i64 @part_1(ptr %buf, i64 %read_bytes)
  call i32 @printf(ptr @str.print.part1, i64 %part_1_answer)

  %part_2_answer = call i64 @part_2(ptr %buf, i64 %read_bytes)
  call i32 @printf(ptr @str.print.part2, i64 %part_2_answer)

  ret i32 0
}
