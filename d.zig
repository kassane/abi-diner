const std = @import("std");
const shared = @import("./shared.zig");
const Tag = shared.Tag;
const FileWriter = std.fs.File.Writer;
const BufWriter = std.io.BufferedWriter(4096, FileWriter).Writer;

pub fn main() !void {
    var args = std.process.args();
    defer std.debug.assert(args.next() == null);

    const argv0 = args.next().?;
    _ = argv0;

    const seed = try std.fmt.parseInt(u64, args.next().?, 10);
    var rand = std.Random.DefaultPrng.init(seed);
    const random = rand.random();

    const count = try std.fmt.parseInt(u8, args.next().?, 10);
    std.debug.assert(count == 1);

    switch (std.meta.stringToEnum(enum { caller, callee }, args.next().?).?) {
        .caller => {
            const tag: Tag = @enumFromInt(try std.fmt.parseInt(u8, args.next().?, 10));

            const stdout = std.io.getStdOut();
            var bw = std.io.bufferedWriter(stdout.writer());
            const writer = bw.writer();

            try writer.writeAll("import core.stdc.stdint;\n");
            try writer.writeAll("import core.stdc.stddef;\n");
            try writer.writeAll("\n");
            try writer.writeAll("@nogc nothrow:");
            try writer.writeAll("\n");
            try writer.writeAll("extern (C) void do_test(");
            try renderType(tag, writer);
            try writer.writeAll(");\n");
            try writer.writeAll("extern (C) void do_caller() {\n");
            try writer.writeAll("    ");
            try renderTypeBacker(tag, writer);
            try writer.writeAll(" v0 = cast(");
            try renderTypeBacker(tag, writer);
            try writer.writeAll(")");
            try renderValue(tag, writer, random);
            try writer.writeAll(";\n");
            try writer.writeAll("    do_test(*cast(");
            try renderType(tag, writer);
            try writer.writeAll("*)&v0);\n");
            try writer.writeAll("}\n");
            try bw.flush();
        },

        .callee => {
            const tag: Tag = @enumFromInt(try std.fmt.parseInt(u8, args.next().?, 10));

            const stdout = std.io.getStdOut();
            var bw = std.io.bufferedWriter(stdout.writer());
            const writer = bw.writer();

            try writer.writeAll("import core.stdc.stdint;\n");
            try writer.writeAll("import core.stdc.stddef;\n");
            try writer.writeAll("\n");
            try writer.writeAll("@nogc nothrow:");
            try writer.writeAll("\n");

            try writer.writeAll("extern (C) void do_panic();\n");
            try writer.writeAll("extern (C) void do_test(");
            try renderType(tag, writer);
            try writer.writeAll(" a0) {\n");
            try writer.writeAll("    ");
            try renderTypeBacker(tag, writer);
            try writer.writeAll(" v0 = cast(");
            try renderTypeBacker(tag, writer);
            try writer.writeAll(")");
            try renderValue(tag, writer, random);
            try writer.writeAll(";\n");
            try writer.writeAll("    if (a0 != *cast(");
            try renderType(tag, writer);
            try writer.writeAll("*)&v0) do_panic();\n");
            try writer.writeAll("}\n");
            try bw.flush();
        },
    }
}

pub fn supportsTag(tag: Tag) bool {
    return switch (tag) {
        .f128 => false, // type doesnt exist
        else => true,
    };
}

pub fn renderType(self: Tag, writer: BufWriter) !void {
    try writer.writeAll(switch (self) {
        .i8 => "byte",
        .i16 => "short",
        .i32 => "int",
        .i64 => "long",
        .i128 => "cent",
        .u8 => "ubyte",
        .u16 => "ushort",
        .u32 => "uint",
        .u64 => "ulong",
        .u128 => "ucent",
        .f16 => "float",
        .f32 => "float",
        .f64 => "double",
        .f128 => @panic("not stable"),
        .bool => "bool",
        .ptr => "void*",
    });
}

pub fn renderTypeBacker(self: Tag, writer: BufWriter) !void {
    try writer.writeAll(switch (self) {
        .u8, .i8 => "ubyte",
        .u16, .i16 => "ushort",
        .u32, .i32 => "uint",
        .u64, .i64 => "ulong",
        .u128, .i128 => "ucent",
        .f16 => "ushort",
        .f32 => "uint",
        .f64 => "ulong",
        .f128 => "cent",
        .bool => "ubyte",
        .ptr => "size_t",
    });
}

pub fn renderValue(self: Tag, writer: BufWriter, random: std.Random) !void {
    switch (self) {
        .u8, .i8 => try writer.print("{d}", .{random.int(u8)}),
        .u16, .i16 => try writer.print("{d}", .{random.int(u16)}),
        .u32, .i32 => try writer.print("{d}", .{random.int(u32)}),
        .u64, .i64 => try writer.print("{d}", .{random.int(u64)}),
        .u128, .i128 => try writer.print("{d}_u128", .{random.int(u128)}),
        .f16 => try writer.print("{d}", .{random.int(u16)}),
        .f32 => try writer.print("{d}", .{random.int(u32)}),
        .f64 => try writer.print("{d}", .{random.int(u64)}),
        .f128 => try writer.print("{d}", .{random.int(u128)}),
        .bool => try writer.print("{d}", .{random.int(u1)}),
        .ptr => try writer.print("{d}", .{random.int(usize)}),
    }
}
