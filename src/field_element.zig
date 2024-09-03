const std = @import("std");
const testing = std.testing;

// field element struct with generic num and prime
pub fn FieldElement(comptime T: type) type {
    return struct {
        num: T,
        prime: T,

        pub fn init(num: T, prime: T) @This() {
            comptime if (@bitSizeOf(T) > 256) {
                @compileError("The type size cannot be larger than u256.");
            };

            if (num >= prime) {
                @panic("Num not in field range 0 to prime");
            }
            return @This(){ .num = num, .prime = prime };
        }

        pub fn eq(self: @This(), rhs: @This()) bool {
            return self.num == rhs.num and self.prime == rhs.prime;
        }

        pub fn ne(self: @This(), rhs: @This()) bool {
            return !self.eq(rhs);
        }

        pub fn add(self: @This(), rhs: @This()) @This() {
            if (self.prime != rhs.prime) {
                @panic("Cannot add two numbers in different fields");
            }
            const n1: u512 = @intCast(self.num);
            const n2: u512 = @intCast(rhs.num);
            const n3: u512 = (n1 + n2) % self.prime;
            const n: T = @truncate(n3);
            return @This(){ .num = n % self.prime, .prime = self.prime };
        }

        pub fn sub(self: @This(), rhs: @This()) @This() {
            if (self.prime != rhs.prime) {
                @panic("Cannot subtract two numbers in different fields");
            }
            const num = if (self.num >= rhs.num) self.num - rhs.num else self.prime - (rhs.num - self.num);
            return @This(){ .num = num, .prime = self.prime };
        }

        pub fn mul(self: @This(), rhs: @This()) @This() {
            if (self.prime != rhs.prime) {
                @panic("Cannot multiply two numbers in different fields");
            }
            const n1: u512 = @intCast(self.num);
            const n2: u512 = @intCast(rhs.num);
            const n3: u512 = (n1 * n2) % self.prime;
            const n: T = @truncate(n3);
            return @This(){ .num = n, .prime = self.prime };
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

        pub fn div(self: @This(), rhs: @This()) @This() {
            if (self.prime != rhs.prime) {
                @panic("Cannot divide two numbers in different fields");
            }
            return self.mul(rhs.pow(self.prime - 2));
        }

        pub fn rmul(self: @This(), coefficient: anytype) @This() {
            const n1: u512 = @intCast(self.num);
            const coef: u512 = @intCast(coefficient);
            const n_: u512 = (n1 * coef) % self.prime;
            const n: T = @truncate(n_);
            return @This(){ .num = n, .prime = self.prime };
        }
    };
}

test "eq" {
    const a = FieldElement(u32).init(7, 13);
    const b = FieldElement(u32).init(6, 13);
    const c = FieldElement(u32).init(6, 13);
    try testing.expect(!a.eq(b));
    try testing.expect(a.ne(b));
    try testing.expect(b.eq(c));
    try testing.expect(!b.ne(c));
}

test "add" {
    {
        const a = FieldElement(u32).init(2, 31);
        const b = FieldElement(u32).init(15, 31);
        const c = FieldElement(u32).init(17, 31);
        try testing.expect(a.add(b).eq(c));
    }

    {
        const a = FieldElement(u32).init(17, 31);
        const b = FieldElement(u32).init(21, 31);
        const c = FieldElement(u32).init(7, 31);
        try testing.expect(a.add(b).eq(c));
    }
}

test "sub" {
    {
        const a = FieldElement(u32).init(29, 31);
        const b = FieldElement(u32).init(4, 31);
        const c = FieldElement(u32).init(25, 31);
        try testing.expect(a.sub(b).eq(c));
    }

    {
        const a = FieldElement(u32).init(15, 31);
        const b = FieldElement(u32).init(30, 31);
        const c = FieldElement(u32).init(16, 31);
        try testing.expect(a.sub(b).eq(c));
    }
}

test "mul" {
    const a = FieldElement(u32).init(24, 31);
    const b = FieldElement(u32).init(19, 31);
    const c = FieldElement(u32).init(22, 31);
    try testing.expect(a.mul(b).eq(c));
}

test "rmul" {
    const a = FieldElement(u32).init(24, 31);
    const b = 2;
    try testing.expect(a.rmul(b).eq(a.add(a)));
}

test "pow" {
    {
        const a = FieldElement(u32).init(17, 31);
        const b = FieldElement(u32).init(15, 31);
        try testing.expect(a.pow(3).eq(b));
    }

    {
        const a = FieldElement(u32).init(5, 31);
        const b = FieldElement(u32).init(18, 31);
        const c = FieldElement(u32).init(16, 31);
        try testing.expect(a.pow(5).mul(b).eq(c));
    }
}

test "div" {
    {
        const a = FieldElement(u32).init(3, 31);
        const b = FieldElement(u32).init(24, 31);
        const c = FieldElement(u32).init(4, 31);
        try testing.expect(a.div(b).eq(c));
    }

    {
        const a = FieldElement(u32).init(1, 31);
        const b = FieldElement(u32).init(17, 31);
        const c = FieldElement(u32).init(29, 31);
        try testing.expect(a.div(b).div(b).div(b).eq(c));
    }
}
