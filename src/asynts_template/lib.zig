const std = @import("std");

const Lexer = @import("./Lexer.zig");

// FIXME: This should not be public.
pub const Parser = @import("./Parser.zig");

pub const evaluate = Parser.evaluate;
pub const evaluateAlloc = Parser.evaluateAlloc;
