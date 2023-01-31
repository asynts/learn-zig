const Self = @This();

input: []const u8,
offset: usize,

pub fn init(input: []const u8) Self {
    return Self{
        .input = input,
        .offset = 0,
    };
}

pub fn isEnd(self: *const Self) bool {
    return self.offset >= self.input.len;
}

pub fn peek(self: *const Self) u8 {
    return self.input[self.offset];
}

pub fn consumeUntil(self: *Self, marker: u8) []const u8 {
    var start_offset = self.offset;

    while (!self.isEnd()) {
        if (self.peek() == marker) {
            return self.input[start_offset..self.offset];
        }
        self.offset += 1;
    }

    return self.input[start_offset..];
}

pub fn consumeChar(self: *Self, char: u8) bool {
    if (self.isEnd()) {
        return false;
    }

    if (self.peek() == char) {
        self.offset += 1;
        return true;
    }

    return false;
}

pub fn consumeString(self: *Self, string: []const u8) bool {
    var start_offset = self.offset;

    for (string) |char| {
        if (!self.consumeChar(char)) {
            self.offset = start_offset;
            return false;
        }
    }

    return true;
}
