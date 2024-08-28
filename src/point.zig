const std = @import("std");

pub fn Point(comptime T: type) type {
    return struct {
        x: ?T,
        y: ?T,
        a: T,
        b: T,

        fn _eq(a: ?T, b: ?T) bool {
            switch (@typeInfo(T)) {
                .Int, .Float => a == b,
                .Struct => @field(T, "eq")(a, b),
                else => @compileError("unsupported type"),
            }
        }

        fn _ne(a: T, b: T) bool {
            return !_eq(a, b);
        }

        fn _add(a: T, b: T) T {
            switch (@typeInfo(T)) {
                .Int, .Float => a + b,
                .Struct => @field(T, "add")(a, b),
                else => @compileError("unsupported type"),
            }
        }

        fn _sub(a: T, b: T) T {
            switch (@typeInfo(T)) {
                .Int, .Float => a - b,
                .Struct => @field(T, "sub")(a, b),
                else => @compileError("unsupported type"),
            }
        }

        fn _mul(a: T, b: T) T {
            std.debug.print("asdf {any}", .{@typeInfo(T)});
            switch (@typeInfo(T)) {
                .Int, .Float => a * b,
                .Struct => @field(T, "mul")(a, b),
                else => @compileError("unsupported type"),
            }
        }

        fn _rmul(a: T, cofficient: anytype) T {
            switch (@typeInfo(T)) {
                .Int, .Float => a * cofficient,
                .Struct => @field(T, "rmul")(a, cofficient),
                else => @compileError("unsupported type"),
            }
        }

        fn _div(a: T, b: T) T {
            switch (@typeInfo(T)) {
                .Int, .Float => a / b,
                .Struct => @field(T, "div")(a, b),
                else => @compileError("unsupported type"),
            }
        }

        pub fn init(x_: ?T, y_: ?T, a: T, b: T) @This() {
            if (x_ == null and y_ == null) {
                return .{ .x = null, .y = null, .a = a, .b = b };
            }

            // FIXME
            const x = x_ orelse @panic("x is null");
            const y = y_ orelse @panic("y is null");

            // y^2 = x^3 + ax + b
            const y2 = _mul(y, y);
            const x3 = _mul(_mul(x, x), x);
            const ax = _mul(a, x);
            const rhs = _add(_add(x3, ax), b);

            if (_ne(y2, rhs)) {
                @panic("not on the curve");
            }

            return .{ .x = x, .y = y, .a = a, .b = b };
        }

        pub fn eq(self: @This(), rhs: @This()) bool {
            return _eq(self.x, rhs.x) and _eq(self.y, rhs.y) and _eq(self.a, rhs.a) and _eq(self.b, rhs.b);
        }

        pub fn ne(self: @This(), rhs: @This()) bool {
            return !eq(self, rhs);
        }

        pub fn add(self: @This(), rhs: @This()) @This() {
            if (_ne(self.a, rhs.a) or _ne(self.b, rhs.b)) {
                @panic("Points are not on the same curve");
            }

            if (self.x == null) {
                return rhs;
            }
            if (rhs.x == null) {
                return self;
            }

            // Case 1: x is equal and y is not equal -> Infinity
            if (_eq(self.x, rhs.x) and _ne(self.y, rhs.y)) {
                return .{ .x = null, .y = null, .a = self.a, .b = self.b };
            }

            // Case 2: x is not equal
            // Formula (x3,y3)==(x1,y1)+(x2,y2)
            // s=(y2-y1)/(x2-x1)
            // x3=s**2-x1-x2
            // y3=s*(x1-x3)-y1
            if (_ne(self.x, rhs.x)) {
                const x1 = self.x;
                const y1 = self.y;
                const x2 = rhs.x;
                const y2 = rhs.y;

                const s = _sub(y2, y1)._div(_sub(x2, x1));
                const x3 = _mul(s, s)._sub(x1)._sub(x2);
                const y3 = _mul(s, _sub(x1, x3))._sub(y1);
                return .{ .x = x3, .y = y3, .a = self.a, .b = self.b };
            }

            // Case 4: tangent to vertical line -> Infinity
            if (eq(self, rhs) and _eq(self.y, _rmul(self.x, 0))) {
                return .{ .x = null, .y = null, .a = self.a, .b = self.b };
            }

            // Case 3: self == other
            // Formula (x3,y3)=(x1,y1)+(x1,y1)
            // s=(3*x1**2+a)/(2*y1)
            // x3=s**2-2*x1
            // y3=s*(x1-x3)-y1
            const s = _rmul(self.x, 3)._mul(self.x)._add(self.a)._div(_rmul(self.y, 2));
            const x3 = _rmul(s, 2)._sub(_rmul(self.x, 2));
            const y3 = _mul(s, _sub(self.x, x3)._sub(self.y1));
            return .{ .x = x3, .y = y3, .a = self.a, .b = self.b };
        }

        pub fn rmul(self: @This(), cofficient: anytype) @This() {
            var coef = cofficient;
            var current = self;
            var result = Point(T).init(null, null, self.a, self.b);
            while (coef > 0) {
                if (coef & 1) {
                    result = result.add(current);
                }
                current = current.add(current);
                coef >>= 1;
            }

            return result;
        }
    };
}

test "ne" {
    const a = Point(i32).init(3, -7, 5, 7);
    const b = Point(i32).init(18, 77, 5, 7);
    try std.testing.expect(a.ne(b));
}

test "point_on_curve" {
    const a = Point(i32).init(3, -7, 5, 7);
    const b = Point(i32).init(18, 77, 5, 7);
    std.debug.print("{any} {any}", .{ a.x, b.x });
}
