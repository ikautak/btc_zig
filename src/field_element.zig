const std = @import("std");

// field element struct with generic num and prime
pub fn FieldElement(comptime T: type) type {
    return struct {
        num: T,
        prime: T,

        pub fn init(num: T, prime: T) @This() {
            if (num >= prime) {
                @panic("Num not in field range 0 to prime");
            }
            return .{ .num = num, .prime = prime };
        }

        pub fn eq(self: @This(), other: @This()) bool {
            return self.num == other.num and self.prime == other.prime;
        }

        pub fn ne(self: @This(), other: @This()) bool {
            return !self.eq(other);
        }

        pub fn add(self: @This(), other: @This()) @This() {
            if (self.prime != other.prime) {
                @panic("Cannot add two numbers in different fields");
            }
            return .{ .num = (self.num + other.num) % self.prime, .prime = self.prime };
        }

        pub fn sub(self: @This(), other: @This()) @This() {
            if (self.prime != other.prime) {
                @panic("Cannot subtract two numbers in different fields");
            }
            const num = if (self.num >= other.num) self.num - other.num else self.prime - (other.num - self.num);
            return .{ .num = num, .prime = self.prime };
        }

        pub fn mul(self: @This(), other: @This()) @This() {
            if (self.prime != other.prime) {
                @panic("Cannot multiply two numbers in different fields");
            }
            return .{ .num = (self.num * other.num) % self.prime, .prime = self.prime };
        }

        pub fn pow(self: @This(), exp: T) @This() {
            var result = FieldElement(T).init(1, self.prime);
            var base = self;
            var exponent = exp;
            while (exponent > 0) {
                if (exponent % 2 == 1) {
                    result = result.mul(base);
                }
                base = base.mul(base);
                exponent = exponent / 2;
            }
            return result;
        }

        pub fn div(self: @This(), other: @This()) @This() {
            if (self.prime != other.prime) {
                @panic("Cannot divide two numbers in different fields");
            }
            return self.mul(other.pow(self.prime - 2));
        }
    };
}

test "eq" {
    const a = FieldElement(u64).init(7, 13);
    const b = FieldElement(u64).init(6, 13);
    const c = FieldElement(u64).init(6, 13);
    try std.testing.expect(!a.eq(b));
    try std.testing.expect(a.ne(b));
    try std.testing.expect(b.eq(c));
    try std.testing.expect(!b.ne(c));
}

test "add" {
    {
        const a = FieldElement(u64).init(2, 31);
        const b = FieldElement(u64).init(15, 31);
        const c = FieldElement(u64).init(17, 31);
        try std.testing.expect(a.add(b).eq(c));
    }

    {
        const a = FieldElement(u64).init(17, 31);
        const b = FieldElement(u64).init(21, 31);
        const c = FieldElement(u64).init(7, 31);
        try std.testing.expect(a.add(b).eq(c));
    }
}

test "sub" {
    {
        const a = FieldElement(u32).init(29, 31);
        const b = FieldElement(u32).init(4, 31);
        const c = FieldElement(u32).init(25, 31);
        try std.testing.expect(a.sub(b).eq(c));
    }

    {
        const a = FieldElement(u32).init(15, 31);
        const b = FieldElement(u32).init(30, 31);
        const c = FieldElement(u32).init(16, 31);
        try std.testing.expect(a.sub(b).eq(c));
    }
}

test "mul" {
    const a = FieldElement(u32).init(24, 31);
    const b = FieldElement(u32).init(19, 31);
    const c = FieldElement(u32).init(22, 31);
    try std.testing.expect(a.mul(b).eq(c));
}

test "pow" {
    {
        const a = FieldElement(u32).init(17, 31);
        const b = FieldElement(u32).init(15, 31);
        try std.testing.expect(a.pow(3).eq(b));
    }

    {
        const a = FieldElement(u32).init(5, 31);
        const b = FieldElement(u32).init(18, 31);
        const c = FieldElement(u32).init(16, 31);
        try std.testing.expect(a.pow(5).mul(b).eq(c));
    }
}

test "div" {
    {
        const a = FieldElement(u32).init(3, 31);
        const b = FieldElement(u32).init(24, 31);
        const c = FieldElement(u32).init(4, 31);
        try std.testing.expect(a.div(b).eq(c));
    }

    {
        const a = FieldElement(u32).init(1, 31);
        const b = FieldElement(u32).init(17, 31);
        const c = FieldElement(u32).init(29, 31);
        try std.testing.expect(a.div(b).div(b).div(b).eq(c));
    }
}
