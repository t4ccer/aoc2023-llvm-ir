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

define i64 @parse.i64(ptr %buf, ptr %idx_ptr) {
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

%map_entry_t = type [3 x i64]

define void @read_map_line(ptr %buf, ptr %idx, ptr %map_entry.ptr) {
  %map_entry.ptr.0 = getelementptr %map_entry_t, ptr %map_entry.ptr, i32 0, i32 0
  %val.0 = call fastcc i64 @parse.i64(ptr %buf, ptr %idx)
  store i64 %val.0, ptr %map_entry.ptr.0
  call fastcc void @incr.i64(ptr %idx)

  %map_entry.ptr.1 = getelementptr %map_entry_t, ptr %map_entry.ptr, i32 0, i32 1
  %val.1 = call fastcc i64 @parse.i64(ptr %buf, ptr %idx)
  store i64 %val.1, ptr %map_entry.ptr.1
  call fastcc void @incr.i64(ptr %idx)

  %map_entry.ptr.2 = getelementptr %map_entry_t, ptr %map_entry.ptr, i32 0, i32 2
  %val.2 = call fastcc i64 @parse.i64(ptr %buf, ptr %idx)
  store i64 %val.2, ptr %map_entry.ptr.2
  call fastcc void @incr.i64(ptr %idx)

  ret void
}

define i64 @read_map(ptr %buf, ptr %idx, ptr %map) {
  call fastcc void @add.i64(ptr %idx, i64 2)
  call fastcc void @skip_to(ptr %buf, ptr %idx, i8 10)

  %entry_idx = alloca i64
  store i64 0, ptr %entry_idx
  br label %loop_start

loop_start:
  %is_newline = call fastcc i1 @char_eq(ptr %buf, ptr %idx, i8 10)
  %is_eof = call fastcc i1 @char_eq(ptr %buf, ptr %idx, i8 0)
  %is_over = or i1 %is_newline, %is_eof
  br i1 %is_over, label %loop_end, label %loop_cont

loop_cont:
  %entry_idx_curr = load i64, ptr %entry_idx
  call fastcc void @incr.i64(ptr %entry_idx)
  %entry_dest_ptr = getelementptr %map_entry_t, ptr %map, i64 %entry_idx_curr, i32 0
  call fastcc void @read_map_line(ptr %buf, ptr %idx, ptr %entry_dest_ptr)

  br label %loop_start

loop_end:
  %entry_count = load i64, ptr %entry_idx
  ret i64 %entry_count
}

define i64 @read_seeds(ptr %buf, ptr %idx, ptr %list) {
  %seed_idx = alloca i64
  store i64 0, ptr %seed_idx

  call fastcc void @add.i64(ptr %idx, i64 6) ;; skip 'seeds:'
  br label %loop_start

loop_start:
  call fastcc void @skip_spaces(ptr %buf, ptr %idx)
  %is_newline = call fastcc i1 @char_eq(ptr %buf, ptr %idx, i8 10)
  br i1 %is_newline, label %loop_end, label %loop_cont

loop_cont:
  %seed = call fastcc i64 @parse.i64(ptr %buf, ptr %idx)

  %seed_idx_val = load i64, ptr %seed_idx
  call fastcc void @incr.i64(ptr %seed_idx)
  %seed_dest.ptr = getelementptr %map_entry_t, ptr %list, i32 0, i64 %seed_idx_val
  store i64 %seed, ptr %seed_dest.ptr

  br label %loop_start

loop_end:
  %seed_count = load i64, ptr %seed_idx
  ret i64 %seed_count
}

define i64 @map_number(i64 %source, ptr %map, i64 %map.len) {
  %idx = alloca i64
  store i64 0, ptr %idx

  br label %loop_start

loop_start:
  %idx_val = load i64, ptr %idx
  call fastcc void @incr.i64(ptr %idx)
  %is_over = icmp eq i64 %idx_val, %map.len
  br i1 %is_over, label %loop_end, label %loop_cont

loop_cont:
  %map_entry.ptr.0 = getelementptr %map_entry_t, ptr %map, i64 %idx_val, i32 0
  %destination_start = load i64, ptr %map_entry.ptr.0

  %map_entry.ptr.1 = getelementptr %map_entry_t, ptr %map, i64 %idx_val, i32 1
  %source_start = load i64, ptr %map_entry.ptr.1

  %map_entry.ptr.2 = getelementptr %map_entry_t, ptr %map, i64 %idx_val, i32 2
  %range_len = load i64, ptr %map_entry.ptr.2

  %source_end = add i64 %source_start, %range_len

  %is_above_start = icmp sge i64 %source, %source_start
  %is_below_end = icmp slt i64 %source, %source_end
  %is_in_range = and i1 %is_above_start, %is_below_end

  br i1 %is_in_range, label %in_range, label %loop_start

in_range:
  %ans.0 = sub i64 %source, %source_start
  %ans = add i64 %ans.0, %destination_start
  ret i64 %ans

loop_end:
  ret i64 %source
}

define void @update_min(ptr %acc.ptr, i64 %value) {
  %curr = load i64, ptr %acc.ptr
  %should_update = icmp ult i64 %value, %curr
  br i1 %should_update, label %do_update, label %dont_update

do_update:
  store i64 %value, ptr %acc.ptr
  ret void

dont_update:
  ret void
}

define i64 @part_1(ptr %buf, i64 %buf_size) {
  %idx = alloca i64
  store i64 0, ptr %idx

  %seeds = alloca [32 x i64]
  %seeds_count = call fastcc i64 @read_seeds(ptr %buf, ptr %idx, ptr %seeds)

  %map.seed_to_soil = alloca [32 x %map_entry_t]
  %map.seed_to_soil.len = call fastcc i64 @read_map(ptr %buf, ptr %idx, ptr %map.seed_to_soil)

  %map.soil_to_fertilizer = alloca [32 x %map_entry_t]
  %map.soil_to_fertilizer.len = call fastcc i64 @read_map(ptr %buf, ptr %idx, ptr %map.soil_to_fertilizer)

  %map.fertilizer_to_water = alloca [32 x %map_entry_t]
  %map.fertilizer_to_water.len = call fastcc i64 @read_map(ptr %buf, ptr %idx, ptr %map.fertilizer_to_water)

  %map.water_to_light = alloca [32 x %map_entry_t]
  %map.water_to_light.len = call fastcc i64 @read_map(ptr %buf, ptr %idx, ptr %map.water_to_light)

  %map.light_to_temperature = alloca [32 x %map_entry_t]
  %map.light_to_temperature.len = call fastcc i64 @read_map(ptr %buf, ptr %idx, ptr %map.light_to_temperature)

  %map.temperature_to_humidity = alloca [32 x %map_entry_t]
  %map.temperature_to_humidity.len = call fastcc i64 @read_map(ptr %buf, ptr %idx, ptr %map.temperature_to_humidity)

  %map.humidity_to_location = alloca [32 x %map_entry_t]
  %map.humidity_to_location.len = call fastcc i64 @read_map(ptr %buf, ptr %idx, ptr %map.humidity_to_location)

  %seed_idx.ptr = alloca i64
  store i64 0, ptr %seed_idx.ptr

  %acc.ptr = alloca i64
  store i64 -1, ptr %acc.ptr

  br label %loop_start

loop_start:
  %seed_idx = load i64, ptr %seed_idx.ptr
  call fastcc void @incr.i64(ptr %seed_idx.ptr)
  %seed_idx.over = icmp eq i64 %seed_idx, %seeds_count
  br i1 %seed_idx.over, label %loop_end, label %loop_cont

loop_cont:
  %seed.ptr = getelementptr i64, ptr %seeds, i64 %seed_idx
  %seed = load i64, ptr %seed.ptr
  %step.0 = call fastcc i64 @map_number(i64 %seed, ptr %map.seed_to_soil, i64 %map.seed_to_soil.len)
  %step.1 = call fastcc i64 @map_number(i64 %step.0, ptr %map.soil_to_fertilizer, i64 %map.soil_to_fertilizer.len)
  %step.2 = call fastcc i64 @map_number(i64 %step.1, ptr %map.fertilizer_to_water, i64 %map.fertilizer_to_water.len)
  %step.3 = call fastcc i64 @map_number(i64 %step.2, ptr %map.water_to_light, i64 %map.water_to_light.len)
  %step.4 = call fastcc i64 @map_number(i64 %step.3, ptr %map.light_to_temperature, i64 %map.light_to_temperature.len)
  %step.5 = call fastcc i64 @map_number(i64 %step.4, ptr %map.temperature_to_humidity, i64 %map.temperature_to_humidity.len)
  %mapped = call fastcc i64 @map_number(i64 %step.5, ptr %map.humidity_to_location, i64 %map.humidity_to_location.len)
  call fastcc void @update_min(ptr %acc.ptr, i64 %mapped)
  br label %loop_start

loop_end:
  %min = load i64, ptr %acc.ptr
  ret i64 %min
}

%list_i64_inner_t = type [ 32 x i64 ]
%list_i64_t = type { i64, %list_i64_inner_t }

define i64 @list_i64_len(ptr %list) {
  %len.ptr = getelementptr i64, ptr %list, i64 0
  %len = load i64, ptr %len.ptr
  ret i64 %len
}

define void @list_i64_pop_from_push_to(ptr %src, ptr %dst) {
  %src.len.ptr = getelementptr i64, ptr %src, i64 0
  br label %loop

loop:
  %src.len = load i64, ptr %src.len.ptr
  %is_done = icmp eq i64 0, %src.len
  br i1 %is_done, label %quit, label %loop_cont

loop_cont:
  %end = call fastcc i64 @list_i64_pop(ptr %src)
  %start = call fastcc i64 @list_i64_pop(ptr %src)
  call fastcc void @list_i64_push_pair(ptr %dst, i64 %start, i64 %end)

  br label %loop

quit:
  ret void
}

define void @list_i64_reset(ptr %list) {
  store i64 0, ptr %list
  ret void
}

define i64 @list_i64_pop(ptr %list) {
  %len = load i64, ptr %list
  %new_len = add i64 %len, -1
  store i64 %new_len, ptr %list
  %elem.ptr = getelementptr %list_i64_t, ptr %list, i64 0, i32 1, i64 %new_len
  %elem = load i64, ptr %elem.ptr
  ret i64 %elem
}

define void @list_i64_push(ptr %list, i64 %value) {
  %len = load i64, ptr %list
  %new_len = add i64 %len, 1
  store i64 %new_len, ptr %list

  %elem.ptr = getelementptr %list_i64_t, ptr %list, i64 0, i32 1, i64 %len
  store i64 %value, ptr %elem.ptr

  ret void
}

define void @list_i64_push_pair(ptr %list, i64 %start, i64 %end) {
  call fastcc void @list_i64_push(ptr %list, i64 %start)
  call fastcc void @list_i64_push(ptr %list, i64 %end)
  ret void
}

define i64 @min(i64 %lhs, i64 %rhs) {
  %c = icmp slt i64 %lhs, %rhs
  br i1 %c, label %l, label %r
l:
  ret i64 %lhs

r:
  ret i64 %rhs
}

define i64 @max(i64 %lhs, i64 %rhs) {
  %c = icmp sgt i64 %lhs, %rhs
  br i1 %c, label %l, label %r
l:
  ret i64 %lhs

r:
  ret i64 %rhs
}

define void @map_range(ptr %input_ranges.ptr, ptr %output_ranges.ptr, ptr %map, i64 %map.len) {
  %all_ranges.ptr = alloca %list_i64_t
  call fastcc void @list_i64_reset(ptr %all_ranges.ptr)

  %new_input_ranges.ptr = alloca %list_i64_t
  call fastcc void @list_i64_reset(ptr %new_input_ranges.ptr)

  %idx = alloca i64
  store i64 0, ptr %idx

  br label %map_loop_start

map_loop_start:
  call fastcc void @list_i64_reset(ptr %new_input_ranges.ptr)
  %idx_val = load i64, ptr %idx
  call fastcc void @incr.i64(ptr %idx)
  %map_is_over = icmp eq i64 %idx_val, %map.len
  br i1 %map_is_over, label %map_loop_end, label %map_loop_cont

map_loop_cont:
  %map_entry.ptr.0 = getelementptr %map_entry_t, ptr %map, i64 %idx_val, i32 0
  %destination_start = load i64, ptr %map_entry.ptr.0

  %map_entry.ptr.1 = getelementptr %map_entry_t, ptr %map, i64 %idx_val, i32 1
  %source_start = load i64, ptr %map_entry.ptr.1

  %map_entry.ptr.2 = getelementptr %map_entry_t, ptr %map, i64 %idx_val, i32 2
  %range_len = load i64, ptr %map_entry.ptr.2

  %source_end = add i64 %source_start, %range_len

  br label %range_loop_start

range_loop_start:
  %input_ranges.len.ptr = getelementptr i64, ptr %input_ranges.ptr, i64 0
  %input_ranges.len = load i64, ptr %input_ranges.len.ptr
  %range_is_done = icmp eq i64 0, %input_ranges.len
  br i1 %range_is_done, label %range_loop_end, label %range_loop_cont

range_loop_cont:
  %range.end = call fastcc i64 @list_i64_pop(ptr %input_ranges.ptr)
  %range.start = call fastcc i64 @list_i64_pop(ptr %input_ranges.ptr)

  %before.end = call fastcc i64 @min(i64 %range.end, i64 %source_start)

  %inter.start = call fastcc i64 @max(i64 %range.start, i64 %source_start)
  %inter.end = call fastcc i64 @min(i64 %source_end, i64 %range.end)

  %after.start = call fastcc i64 @max(i64 %source_end, i64 %range.start)

  %is_c1 = icmp sgt i64 %before.end, %range.start
  br i1 %is_c1, label %c1, label %not_c1

c1:
  call fastcc void @list_i64_push_pair(ptr %new_input_ranges.ptr, i64 %range.start, i64 %before.end)
  br label %not_c1

not_c1:
  %is_c2 = icmp sgt i64 %inter.end, %inter.start
  br i1 %is_c2, label %c2, label %not_c2

c2:
  %a.offset = sub i64 %destination_start, %source_start
  %a.start = add i64 %inter.start, %a.offset
  %a.end = add i64 %inter.end, %a.offset
  call fastcc void @list_i64_push_pair(ptr %all_ranges.ptr, i64 %a.start, i64 %a.end)
  br label %not_c2

not_c2:
  %is_c3 = icmp sgt i64 %range.end, %after.start
  br i1 %is_c3, label %c3, label %not_c3

c3:
  call fastcc void @list_i64_push_pair(ptr %new_input_ranges.ptr, i64 %after.start, i64 %range.end)
  br label %not_c3

not_c3:
  br label %range_loop_start

range_loop_end:
  call fastcc void @list_i64_pop_from_push_to(ptr %new_input_ranges.ptr, ptr %input_ranges.ptr)
  br label %map_loop_start

map_loop_end:
  call fastcc void @list_i64_pop_from_push_to(ptr %all_ranges.ptr, ptr %output_ranges.ptr)
  call fastcc void @list_i64_pop_from_push_to(ptr %input_ranges.ptr, ptr %output_ranges.ptr)
  ret void
}

define void @update_min_in_range(ptr %acc.min, ptr %list) {
  %len.ptr = getelementptr i64, ptr %list, i32 0
  %len_start = load i64, ptr %len.ptr
  br label %loop

loop:
  %len = load i64, ptr %len.ptr
  %is_done = icmp eq i64 0, %len
  br i1 %is_done, label %quit, label %loop_cont

loop_cont:
  %end = call fastcc i64 @list_i64_pop(ptr %list)
  %start = call fastcc i64 @list_i64_pop(ptr %list)
  call fastcc void @update_min(ptr %acc.min, i64 %start)
  br label %loop

quit:
  ret void
}

define i64 @part_2(ptr %buf, i64 %buf_size) {
  %idx = alloca i64
  store i64 0, ptr %idx

  %seeds = alloca [32 x i64]
  %seeds_count = call fastcc i64 @read_seeds(ptr %buf, ptr %idx, ptr %seeds)

  %map.seed_to_soil = alloca [32 x %map_entry_t]
  %map.seed_to_soil.len = call fastcc i64 @read_map(ptr %buf, ptr %idx, ptr %map.seed_to_soil)

  %map.soil_to_fertilizer = alloca [32 x %map_entry_t]
  %map.soil_to_fertilizer.len = call fastcc i64 @read_map(ptr %buf, ptr %idx, ptr %map.soil_to_fertilizer)

  %map.fertilizer_to_water = alloca [32 x %map_entry_t]
  %map.fertilizer_to_water.len = call fastcc i64 @read_map(ptr %buf, ptr %idx, ptr %map.fertilizer_to_water)

  %map.water_to_light = alloca [32 x %map_entry_t]
  %map.water_to_light.len = call fastcc i64 @read_map(ptr %buf, ptr %idx, ptr %map.water_to_light)

  %map.light_to_temperature = alloca [32 x %map_entry_t]
  %map.light_to_temperature.len = call fastcc i64 @read_map(ptr %buf, ptr %idx, ptr %map.light_to_temperature)

  %map.temperature_to_humidity = alloca [32 x %map_entry_t]
  %map.temperature_to_humidity.len = call fastcc i64 @read_map(ptr %buf, ptr %idx, ptr %map.temperature_to_humidity)

  %map.humidity_to_location = alloca [32 x %map_entry_t]
  %map.humidity_to_location.len = call fastcc i64 @read_map(ptr %buf, ptr %idx, ptr %map.humidity_to_location)

  %seed_idx.ptr = alloca i64
  store i64 0, ptr %seed_idx.ptr

  %acc.ptr = alloca i64
  store i64 -1, ptr %acc.ptr

  br label %loop_start

loop_start:
  %ranges_a = alloca %list_i64_t
  %ranges_b = alloca %list_i64_t

  %seed_start_idx = load i64, ptr %seed_idx.ptr

  %seed_range_idx = add i64 %seed_start_idx, 1
  call fastcc void @add.i64(ptr %seed_idx.ptr, i64 2)

  %seed_idx.over = icmp eq i64 %seed_start_idx, %seeds_count
  br i1 %seed_idx.over, label %loop_end, label %loop_cont

loop_cont:
  %seed_start_ptr = getelementptr i64, ptr %seeds, i64 %seed_start_idx
  %seed_start = load i64, ptr %seed_start_ptr ; inclusive

  %seed_range_ptr = getelementptr i64, ptr %seeds, i64 %seed_range_idx
  %seed_range = load i64, ptr %seed_range_ptr

  %seed_end = add i64 %seed_start, %seed_range ; exclusive

  call fastcc void @list_i64_reset(ptr %ranges_a)
  call fastcc void @list_i64_push_pair(ptr %ranges_a, i64 %seed_start, i64 %seed_end)

  call fastcc void @list_i64_reset(ptr %ranges_b)
  call fastcc void @map_range(ptr %ranges_a, ptr %ranges_b, ptr %map.seed_to_soil, i64 %map.seed_to_soil.len)

  call fastcc void @list_i64_reset(ptr %ranges_a)
  call fastcc void @map_range(ptr %ranges_b, ptr %ranges_a, ptr %map.soil_to_fertilizer, i64 %map.soil_to_fertilizer.len)

  call fastcc void @list_i64_reset(ptr %ranges_b)
  call fastcc void @map_range(ptr %ranges_a, ptr %ranges_b, ptr %map.fertilizer_to_water, i64 %map.fertilizer_to_water.len)

  call fastcc void @list_i64_reset(ptr %ranges_a)
  call fastcc void @map_range(ptr %ranges_b, ptr %ranges_a, ptr %map.water_to_light, i64 %map.water_to_light.len)

  call fastcc void @list_i64_reset(ptr %ranges_b)
  call fastcc void @map_range(ptr %ranges_a, ptr %ranges_b, ptr %map.light_to_temperature, i64 %map.light_to_temperature.len)

  call fastcc void @list_i64_reset(ptr %ranges_a)
  call fastcc void @map_range(ptr %ranges_b, ptr %ranges_a, ptr %map.temperature_to_humidity, i64 %map.temperature_to_humidity.len)

  call fastcc void @list_i64_reset(ptr %ranges_b)
  call fastcc void @map_range(ptr %ranges_a, ptr %ranges_b, ptr %map.humidity_to_location, i64 %map.humidity_to_location.len)

  call fastcc void @update_min_in_range(ptr %acc.ptr, ptr %ranges_b)

  br label %loop_start

loop_end:
  %min = load i64, ptr %acc.ptr
  ret i64 %min
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
