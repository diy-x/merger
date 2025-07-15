//! 文件分卷合并工具
//! 用于合并由split命令生成的分卷文件

const std = @import("std");
const print = std.debug.print;
const ArrayList = std.ArrayList;
const Allocator = std.mem.Allocator;

const MergerError = error{
    InvalidArguments,
    FileNotFound,
    InsufficientParts,
    NoPartsFound,
};

const PartFile = struct {
    path: []const u8,
    part_number: u32,

    fn deinit(self: *PartFile, allocator: Allocator) void {
        allocator.free(self.path);
    }
};

/// 打印使用说明
fn printUsage(program_name: []const u8) void {
    print("文件分卷合并工具\n", .{});
    print("使用方法: {s} <输入目录> <输出文件名>\n", .{program_name});
    print("\n", .{});
    print("示例: {s} ./parts ubuntu-24.04.img.xz\n", .{program_name});
    print("\n", .{});
    print("说明:\n", .{});
    print("  - 输入目录: 包含.part文件的目录\n", .{});
    print("  - 输出文件名: 合并后的文件名\n", .{});
    print("  - 工具会自动识别并按顺序合并所有分卷文件\n", .{});
}

/// 从文件名中提取分卷号
fn extractPartNumber(filename: []const u8) ?u32 {
    const part_prefix = ".part";

    if (std.mem.indexOf(u8, filename, part_prefix)) |part_index| {
        const number_start = part_index + part_prefix.len;
        if (number_start < filename.len) {
            const number_str = filename[number_start..];
            return std.fmt.parseInt(u32, number_str, 10) catch null;
        }
    }
    return null;
}

/// 查找并排序分卷文件
fn findPartFiles(allocator: Allocator, dir_path: []const u8) !ArrayList(PartFile) {
    var parts = ArrayList(PartFile).init(allocator);
    errdefer {
        for (parts.items) |*part| {
            part.deinit(allocator);
        }
        parts.deinit();
    }

    var dir = std.fs.cwd().openDir(dir_path, .{ .iterate = true }) catch |err| {
        print("错误: 无法打开目录 '{s}': {}\n", .{ dir_path, err });
        return err;
    };
    defer dir.close();

    var iterator = dir.iterate();
    while (try iterator.next()) |entry| {
        if (entry.kind != .file) continue;

        if (extractPartNumber(entry.name)) |part_number| {
            const full_path = try std.fs.path.join(allocator, &[_][]const u8{ dir_path, entry.name });

            const part = PartFile{
                .path = full_path,
                .part_number = part_number,
            };

            try parts.append(part);
        }
    }

    if (parts.items.len == 0) {
        print("错误: 在目录 '{s}' 中未找到任何分卷文件\n", .{dir_path});
        return MergerError.NoPartsFound;
    }

    // 按分卷号排序
    std.sort.insertion(PartFile, parts.items, {}, struct {
        fn lessThan(context: void, a: PartFile, b: PartFile) bool {
            _ = context;
            return a.part_number < b.part_number;
        }
    }.lessThan);

    return parts;
}

/// 格式化字节数为人类可读的格式
fn formatBytes(allocator: Allocator, bytes: u64) ![]u8 {
    if (bytes < 1024) {
        return try std.fmt.allocPrint(allocator, "{d} B", .{bytes});
    } else if (bytes < 1024 * 1024) {
        return try std.fmt.allocPrint(allocator, "{d:.1} KB", .{@as(f64, @floatFromInt(bytes)) / 1024.0});
    } else if (bytes < 1024 * 1024 * 1024) {
        return try std.fmt.allocPrint(allocator, "{d:.1} MB", .{@as(f64, @floatFromInt(bytes)) / (1024.0 * 1024.0)});
    } else {
        return try std.fmt.allocPrint(allocator, "{d:.1} GB", .{@as(f64, @floatFromInt(bytes)) / (1024.0 * 1024.0 * 1024.0)});
    }
}

/// 合并分卷文件
fn mergePartFiles(allocator: Allocator, parts: ArrayList(PartFile), output_path: []const u8) !void {
    const output_file = std.fs.cwd().createFile(output_path, .{}) catch |err| {
        print("错误: 无法创建输出文件 '{s}': {}\n", .{ output_path, err });
        return err;
    };
    defer output_file.close();

    const buffer_size = 1024 * 1024; // 1MB buffer
    var buffer = try allocator.alloc(u8, buffer_size);
    defer allocator.free(buffer);

    var total_bytes: u64 = 0;

    print("开始合并 {} 个分卷文件到 '{s}'\n", .{ parts.items.len, output_path });

    for (parts.items, 0..) |part, index| {
        print("正在处理分卷 {} / {}: {s}\n", .{ index + 1, parts.items.len, part.path });

        const part_file = std.fs.cwd().openFile(part.path, .{}) catch |err| {
            print("错误: 无法打开分卷文件 '{s}': {}\n", .{ part.path, err });
            return err;
        };
        defer part_file.close();

        var part_bytes: u64 = 0;

        while (true) {
            const bytes_read = try part_file.readAll(buffer);
            if (bytes_read == 0) break;

            try output_file.writeAll(buffer[0..bytes_read]);
            part_bytes += bytes_read;
            total_bytes += bytes_read;
        }

        const size_str = try formatBytes(allocator, part_bytes);
        defer allocator.free(size_str);
        print("  已处理: {s}\n", .{size_str});
    }

    const total_size_str = try formatBytes(allocator, total_bytes);
    defer allocator.free(total_size_str);
    print("合并完成! 总大小: {s}\n", .{total_size_str});
}

/// 验证分卷文件的连续性
fn validatePartSequence(parts: ArrayList(PartFile)) !void {
    for (parts.items, 1..) |part, expected_number| {
        if (part.part_number != expected_number) {
            print("错误: 分卷序列不连续。期望分卷号 {d}，但找到 {d}\n", .{ expected_number, part.part_number });
            return MergerError.InsufficientParts;
        }
    }
}

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);

    if (args.len != 3) {
        printUsage(args[0]);
        return MergerError.InvalidArguments;
    }

    const input_dir = args[1];
    const output_file = args[2];

    print("输入目录: {s}\n", .{input_dir});
    print("输出文件: {s}\n", .{output_file});
    print("\n", .{});

    // 查找分卷文件
    var parts = findPartFiles(allocator, input_dir) catch |err| {
        return err;
    };
    defer {
        for (parts.items) |*part| {
            part.deinit(allocator);
        }
        parts.deinit();
    }

    // 验证分卷序列
    try validatePartSequence(parts);

    print("找到 {} 个分卷文件:\n", .{parts.items.len});
    for (parts.items) |part| {
        print("  分卷 {d}: {s}\n", .{ part.part_number, part.path });
    }
    print("\n", .{});

    // 合并文件
    try mergePartFiles(allocator, parts, output_file);
}
