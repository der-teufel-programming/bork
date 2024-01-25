const Config = @This();
const std = @import("std");

ctrl_c_protection: bool = false,
notifications: struct {
    follows: bool = true,
    charity: bool = true,
} = .{},

pub fn get(gpa: std.mem.Allocator, config_base: std.fs.Dir) !Config {
    const file = config_base.openFile("bork/config.json", .{}) catch |err| switch (err) {
        else => return err,
        error.FileNotFound => return create(config_base),
    };
    defer file.close();

    const config_json = try file.reader().readAllAlloc(gpa, 4096);
    defer gpa.free(config_json);

    return std.json.parseFromSliceLeaky(Config, gpa, config_json, .{
        .allocate = .alloc_always,
        .ignore_unknown_fields = true,
    });
}

pub fn create(config_base: std.fs.Dir) !Config {
    const in = std.io.getStdIn();
    const in_reader = in.reader();

    std.debug.print(
        \\
        \\Hi, welcome to Bork!
        \\This is the initial setup procedure that will 
        \\help you create an initial config file.
        \\
    , .{});

    // Inside this scope user input is set to immediate mode.
    const protection: bool = blk: {
        const original_termios = try std.os.tcgetattr(in.handle);
        defer std.os.tcsetattr(in.handle, .FLUSH, original_termios) catch {};
        {
            var termios = original_termios;
            // set immediate input mode
            termios.lflag &= ~@as(std.os.system.tcflag_t, std.os.system.ICANON);
            try std.os.tcsetattr(in.handle, .FLUSH, termios);

            std.debug.print(
                \\ 
                \\=============================================================
                \\
                \\Bork allows you to interact with it in three ways: 
                \\ 
                \\- Keyboard
                \\  Up/Down Arrows and Page Up/Down will allow you to
                \\  scroll message history.
                \\
                \\- Mouse 
                \\  Left click on messages to highlight them, clicking
                \\  on the message author will toggle highlight all 
                \\  messages from that same user.
                \\  Wheel Up/Down to scroll message history.
                \\
                \\- Remote CLI
                \\  By invoking the `bork` command in a shell you will 
                \\  be able to issue various commands, from sending 
                \\  messages to issuing bans. See the full list of 
                \\  commands by calling `bork help`.
                \\
                \\Press any key to continue reading...
                \\
                \\
            , .{});

            _ = try in_reader.readByte();

            std.debug.print(
                \\         ======> ! IMPORTANT ! <======
                \\To protect you from accidentally closing Bork while
                \\streaming, with CTRL+C protection enabled, Bork will
                \\not close when you press CTRL+C. 
                \\
                \\To close it, you will instead have to execute in a 
                \\separate shell:
                \\
                \\                `bork quit`
                \\ 
                \\Enable CTRL+C protection? [Y/n] 
            , .{});

            const enable = try in_reader.readByte();
            switch (enable) {
                else => {
                    std.debug.print(
                        \\
                        \\
                        \\CTRL+C protection is disabled.
                        \\You can enable it in the future by editing the 
                        \\configuration file.
                        \\ 
                        \\
                    , .{});
                    break :blk false;
                },
                'y', 'Y', '\n' => {
                    break :blk true;
                },
            }
        }
    };

    const result: Config = .{ .ctrl_c_protection = protection };

    // create the config file
    var file = try config_base.createFile("bork/config.json", .{});
    defer file.close();
    try std.json.stringify(result, .{}, file.writer());

    return result;
}
