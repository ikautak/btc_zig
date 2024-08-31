const std = @import("std");
const testing = std.testing;

pub fn Point(comptime T: type) type {
    return struct {
        x: ?T,
        y: ?T,
        a: T,
        b: T,

        fn _eq(a: ?T, b: ?T) bool {
            return switch (@typeInfo(T)) {
                .Int, .Float => a == b,
                .Struct => @field(T, "eq")(a.?, b.?),
                else => @compileError("unsupported type"),
            };
        }

        fn _ne(a: T, b: T) bool {
            return !_eq(a, b);
        }

        fn _add(a: T, b: T) T {
            return switch (@typeInfo(T)) {
                .Int, .Float => a + b,
                .Struct => @field(T, "add")(a, b),
                else => @compileError("unsupported type"),
            };
        }

        fn _sub(a: T, b: T) T {
            return switch (@typeInfo(T)) {
                .Int, .Float => a - b,
                .Struct => @field(T, "sub")(a, b),
                else => @compileError("unsupported type"),
            };
        }

        fn _mul(a: T, b: T) T {
            return switch (@typeInfo(T)) {
                .Int, .Float => a * b,
                .Struct => @field(T, "mul")(a, b),
                else => @compileError("unsupported type"),
            };
        }

        fn _rmul(a: T, coefficient: anytype) T {
            return switch (@typeInfo(T)) {
                .Int, .Float => a * coefficient,
                .Struct => @field(T, "rmul")(a, coefficient),
                else => @compileError("unsupported type"),
            };
        }

        fn _div(a: T, b: T) T {
            return switch (@typeInfo(T)) {
                .Int, .Float => @divTrunc(a, b),
                .Struct => @field(T, "div")(a, b),
                else => @compileError("unsupported type"),
            };
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

            const x1 = self.x orelse @panic("x1 is null");
            const y1 = self.y orelse @panic("y1 is null");
            const x2 = rhs.x orelse @panic("x2 is null");
            const y2 = rhs.y orelse @panic("y2 is null");

            // Case 1: x is equal and y is not equal -> Infinity
            if (_eq(x1, x2) and _ne(y1, y2)) {
                return .{ .x = null, .y = null, .a = self.a, .b = self.b };
            }

            // Case 2: x is not equal
            // Formula (x3,y3)==(x1,y1)+(x2,y2)
            // s=(y2-y1)/(x2-x1)
            // x3=s**2-x1-x2
            // y3=s*(x1-x3)-y1
            if (_ne(x1, x2)) {
                const s = _div(_sub(y2, y1), _sub(x2, x1));
                const x3 = _sub(_sub(_mul(s, s), x1), x2);
                const y3 = _sub(_mul(s, _sub(x1, x3)), y1);
                return .{ .x = x3, .y = y3, .a = self.a, .b = self.b };
            }

            // Case 4: tangent to vertical line -> Infinity
            if (eq(self, rhs) and _eq(y1, _rmul(x1, 0))) {
                return .{ .x = null, .y = null, .a = self.a, .b = self.b };
            }

            // Case 3: self == other
            // Formula (x3,y3)=(x1,y1)+(x1,y1)
            // s=(3*x1**2+a)/(2*y1)
            // x3=s**2-2*x1
            // y3=s*(x1-x3)-y1
            const s = _div(_add(_mul(_rmul(x1, 3), x1), self.a), _rmul(y1, 2));
            const x3 = _sub(_mul(s, s), _rmul(x1, 2));
            const y3 = _sub(_mul(s, _sub(x1, x3)), y1);
            return .{ .x = x3, .y = y3, .a = self.a, .b = self.b };
        }

        pub fn rmul(self: @This(), coefficient: anytype) @This() {
            var coef = coefficient;
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
    try testing.expect(a.ne(b));
}

test "point_on_curve" {
    const a = Point(i32).init(3, -7, 5, 7);
    const b = Point(i32).init(18, 77, 5, 7);
    std.debug.print("{any} {any}", .{ a.x, b.x });
}

//test "point_on_curve_panic" {
//    const a = Point(i32).init(-2, 4, 5, 7);
//    std.debug.print("{any}", .{a});
//}

test "add0" {
    const a = Point(i32).init(null, null, 5, 7);
    const b = Point(i32).init(2, 5, 5, 7);
    const c = Point(i32).init(2, -5, 5, 7);
    try testing.expect(a.add(b).eq(b));
    try testing.expect(b.add(a).eq(b));
    try testing.expect(b.add(c).eq(a));
}

test "add1" {
    const a = Point(i32).init(3, 7, 5, 7);
    const b = Point(i32).init(-1, -1, 5, 7);
    const c = Point(i32).init(2, -5, 5, 7);
    try testing.expect(a.add(b).eq(c));
}

test "add2" {
    const a = Point(i32).init(-1, 1, 5, 7);
    const b = Point(i32).init(18, -77, 5, 7);
    try testing.expect(a.add(a).eq(b));
}
