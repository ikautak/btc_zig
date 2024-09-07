const std = @import("std");
const testing = std.testing;
const FieldElement = @import("field_element.zig").FieldElement;
const Point = @import("point.zig").Point;
const native_endian = @import("builtin").target.cpu.arch.endian();

pub fn modmul(comptime T: type, a: T, b: T, m: T) T {
    comptime if (@bitSizeOf(T) > 256) {
        @compileError("The type size cannot be larger than u256.");
    };

    const a_: u512 = @intCast(a);
    const b_: u512 = @intCast(b);
    const n: u512 = (a_ * b_) % m;
    const result: T = @truncate(n);
    return result;
}

pub fn modpow(comptime T: type, x: T, exp: T, m: T) T {
    var result: T = 1;
    var x_ = x;
    var exp_ = exp;
    while (exp_ > 0) {
        if (exp_ % 2 == 1) {
            result = modmul(T, result, x_, m);
        }
        x_ = modmul(T, x_, x_, m);
        exp_ /= 2;
    }

    return result;
}

const A: u256 = 0;
const B: u256 = 7;
pub const P: u256 = 0xfffffffffffffffffffffffffffffffffffffffffffffffffffffffefffffc2f;
pub const N: u256 = 0xfffffffffffffffffffffffffffffffebaaedce6af48a03bbfd25e8cd0364141;

const S256Field = FieldElement(u256);

pub fn Signature() type {
    return struct {
        r: u256,
        s: u256,

        pub fn init(r: u256, s: u256) @This() {
            return .{ .r = r, .s = s };
        }
    };
}

pub fn S256Point() type {
    return struct {
        point: Point(S256Field),

        pub fn init(x: u256, y: u256) @This() {
            const a = S256Field.init(A, P);
            const b = S256Field.init(B, P);
            const x_ = S256Field.init(x, P);
            const y_ = S256Field.init(y, P);
            return @This(){ .point = Point(S256Field).init(x_, y_, a, b) };
        }

        pub fn mul(self: @This(), coefficient: u256) @This() {
            const coef = coefficient % N;
            return @This(){ .point = self.point.rmul(coef) };
        }

        pub fn verify(self: @This(), z: u256, sig: Signature()) bool {
            const s_inv = modpow(u256, sig.s, N - 2, N);
            const u = modmul(u256, z, s_inv, N);
            const v = modmul(u256, sig.r, s_inv, N);
            const total = G.mul(u).point.add(self.mul(v).point);
            return total.x.?.num == sig.r;
        }

        pub fn sec(self: @This(), compressed: bool) ![]u8 {
            const allocator = std.heap.page_allocator;
            var out = std.ArrayList(u8).init(allocator);

            if (compressed) {
                if (self.point.y.?.num % 2 == 0) {
                    try out.append(0x02);
                } else {
                    try out.append(0x03);
                }

                const x = endian: {
                    switch (native_endian) {
                        .big => {
                            break :endian self.point.x.?.num;
                        },
                        .little => {
                            break :endian @byteSwap(self.point.x.?.num);
                        },
                    }
                };

                for (std.mem.toBytes(x)) |byte| {
                    try out.append(byte);
                }
            } else {
                try out.append(0x04);

                const x = endian: {
                    switch (native_endian) {
                        .big => {
                            break :endian self.point.x.?.num;
                        },
                        .little => {
                            break :endian @byteSwap(self.point.x.?.num);
                        },
                    }
                };
                const y = endian: {
                    switch (native_endian) {
                        .big => {
                            break :endian self.point.y.?.num;
                        },
                        .little => {
                            break :endian @byteSwap(self.point.y.?.num);
                        },
                    }
                };

                for (std.mem.toBytes(x)) |byte| {
                    try out.append(byte);
                }
                for (std.mem.toBytes(y)) |byte| {
                    try out.append(byte);
                }
            }

            return out.toOwnedSlice();
        }
    };
}

pub const G = S256Point().init(0x79be667ef9dcbbac55a06295ce870b07029bfcdb2dce28d959f2815b16f81798, 0x483ada7726a3c4655da4fbfc0e1108a8fd17b448a68554199c47d08ffb10d4b8);

test "on_curve" {
    const prime: u32 = 223;
    const a = FieldElement(u32).init(0, prime);
    const b = FieldElement(u32).init(7, prime);

    const valid_points: [3][2]u32 = .{
        .{ 192, 105 },
        .{ 17, 56 },
        .{ 1, 193 },
    };

    for (valid_points) |point| {
        const x: ?FieldElement(u32) = FieldElement(u32).init(point[0], prime);
        const y: ?FieldElement(u32) = FieldElement(u32).init(point[1], prime);
        const p = Point(FieldElement(u32)).init(x, y, a, b);
        try testing.expectEqual(p.x.?.num, point[0]);
    }
}

//test "on_curve_panic0" {
//    const prime: u32 = 223;
//    const a = FieldElement(u32).init(0, prime);
//    const b = FieldElement(u32).init(7, prime);
//    const x = FieldElement(u32).init(200, prime);
//    const y = FieldElement(u32).init(119, prime);
//    const p = Point(FieldElement(u32)).init(x, y, a, b);
//    _ = p;
//}

//test "on_curve_panic1" {
//    const prime: u32 = 223;
//    const a = FieldElement(u32).init(0, prime);
//    const b = FieldElement(u32).init(7, prime);
//    const x = FieldElement(u32).init(42, prime);
//    const y = FieldElement(u32).init(99, prime);
//    const p = Point(FieldElement(u32)).init(x, y, a, b);
//    _ = p;
//}

test "ecc_add" {
    const prime: u32 = 223;
    const a = FieldElement(u32).init(0, prime);
    const b = FieldElement(u32).init(7, prime);

    const additions: [3][6]u32 = .{
        // x1, y1, x2, y2, x3, y3
        .{ 192, 105, 17, 56, 170, 142 },
        .{ 47, 71, 117, 141, 60, 139 },
        .{ 143, 98, 76, 66, 47, 71 },
    };

    for (additions) |add| {
        const x1 = FieldElement(u32).init(add[0], prime);
        const y1 = FieldElement(u32).init(add[1], prime);
        const p1 = Point(FieldElement(u32)).init(x1, y1, a, b);

        const x2 = FieldElement(u32).init(add[2], prime);
        const y2 = FieldElement(u32).init(add[3], prime);
        const p2 = Point(FieldElement(u32)).init(x2, y2, a, b);

        const x3 = FieldElement(u32).init(add[4], prime);
        const y3 = FieldElement(u32).init(add[5], prime);
        const p3 = Point(FieldElement(u32)).init(x3, y3, a, b);

        try testing.expect(p1.add(p2).eq(p3));
    }
}

test "ecc_scalar_mul" {
    const prime: u32 = 223;
    const a = FieldElement(u32).init(0, prime);
    const b = FieldElement(u32).init(7, prime);
    const multiplications: [5][5]u32 = .{
        // (coefficient, x1, y1, x2, y2)
        .{ 2, 192, 105, 49, 71 },
        .{ 2, 143, 98, 64, 168 },
        .{ 2, 47, 71, 36, 111 },
        .{ 4, 47, 71, 194, 51 },
        .{ 8, 47, 71, 116, 55 },
    };

    for (multiplications) |multi| {
        const x1 = FieldElement(u32).init(multi[1], prime);
        const y1 = FieldElement(u32).init(multi[2], prime);
        const p1 = Point(FieldElement(u32)).init(x1, y1, a, b);

        const x2 = FieldElement(u32).init(multi[3], prime);
        const y2 = FieldElement(u32).init(multi[4], prime);
        const p2 = Point(FieldElement(u32)).init(x2, y2, a, b);

        try testing.expect(p1.rmul(multi[0]).eq(p2));
    }
}

test "ecc_scalar_mul_none" {
    const prime: u32 = 223;
    const a = FieldElement(u32).init(0, prime);
    const b = FieldElement(u32).init(7, prime);
    const s: u32 = 21;

    const x1 = FieldElement(u32).init(47, prime);
    const y1 = FieldElement(u32).init(71, prime);
    const p1 = Point(FieldElement(u32)).init(x1, y1, a, b);
    const p2 = Point(FieldElement(u32)).init(null, null, a, b);

    try testing.expect(p1.rmul(s).eq(p2));
}

test "s256_order" {
    //@import("std").testing.refAllDeclsRecursive(@This());
    const s256point = G.mul(N);
    try std.testing.expectEqual(null, s256point.point.x);
}

test "s256_pub_point" {
    // secret, x, y
    const points: [4][3]u256 = .{
        .{ 7, 0x5cbdf0646e5db4eaa398f365f2ea7a0e3d419b7e0330e39ce92bddedcac4f9bc, 0x6aebca40ba255960a3178d6d861a54dba813d0b813fde7b5a5082628087264da },
        .{ 1485, 0xc982196a7466fbbbb0e27a940b6af926c1a74d5ad07128c82824a11b5398afda, 0x7a91f9eae64438afb9ce6448a1c133db2d8fb9254e4546b6f001637d50901f55 },
        .{ 0x100000000000000000000000000000000, 0x8f68b9d2f63b5f339239c1ad981f162ee88c5678723ea3351b7b444c9ec4c0da, 0x662a9f2dba063986de1d90c2b6be215dbbea2cfe95510bfdf23cbf79501fff82 },
        .{ 0x1000000000000000000000000000000000000000000000000000080000000, 0x9577ff57c8234558f293df502ca4f09cbc65a6572c842b39b366f21717945116, 0x10b49c67fa9365ad7b90dab070be339a1daf9052373ec30ffae4f72d5e66d053 },
    };

    for (points) |point| {
        const p = S256Point().init(point[1], point[2]);
        try testing.expect(G.mul(point[0]).point.eq(p.point));
    }
}

test "s256_verify" {
    const point = S256Point().init(0x887387e452b8eacc4acfde10d9aaf7f6d9a0f975aabb10d006e4da568744d06c, 0x61de6d95231cd89026e286df3b6ae4a894a3378e393e93a0f45b666329a0ae34);
    {
        const z: u256 = 0xec208baa0fc1c19f708a9ca96fdeff3ac3f230bb4a7ba4aede4942ad003c0f60;
        const r: u256 = 0xac8d1c87e51d0d441be8b3dd5b05c8795b48875dffe00b7ffcfac23010d3a395;
        const s: u256 = 0x68342ceff8935ededd102dd876ffd6ba72d6a427a3edb13d26eb0781cb423c4;
        const sig = Signature().init(r, s);
        try testing.expect(point.verify(z, sig));
    }
    {
        const z: u256 = 0x7c076ff316692a3d7eb3c3bb0f8b1488cf72e1afcd929e29307032997a838a3d;
        const r: u256 = 0xeff69ef2b1bd93a66ed5219add4fb51e11a840f404876325a1e8ffe0529a2c;
        const s: u256 = 0xc7207fee197d27c618aea621406f6bf5ef6fca38681d82b2f06fddbdce6feab6;
        const sig = Signature().init(r, s);
        try testing.expect(point.verify(z, sig));
    }
}

test "s256_sec" {
    // case 1
    {
        const coefficient: u32 = std.math.pow(u32, 999, 3);
        const point = G.mul(coefficient);

        {
            const sec = point.sec(false) catch |err| {
                std.debug.panic("failed sec {}", .{err});
            };
            var buf: [256]u8 = undefined;
            const uncompressed = "049d5ca49670cbe4c3bfa84c96a8c87df086c6ea6a24ba6b809c9de234496808d56fa15cc7f3d38cda98dee2419f415b7513dde1301f8643cd9245aea7f3f911f9";
            const uncompressed_u8 = try std.fmt.hexToBytes(&buf, uncompressed);
            try testing.expectEqualSlices(u8, sec, uncompressed_u8);
        }
        {
            const sec = point.sec(true) catch |err| {
                std.debug.panic("failed sec {}", .{err});
            };
            var buf: [256]u8 = undefined;
            const compressed = "039d5ca49670cbe4c3bfa84c96a8c87df086c6ea6a24ba6b809c9de234496808d5";
            const compressed_u8 = try std.fmt.hexToBytes(&buf, compressed);
            try testing.expectEqualSlices(u8, sec, compressed_u8);
        }
    }

    //        // case 2
    //        let coefficient = U512::from(123u32);
    //        let point = G.mul(coefficient);
    //
    //        let sec = point.sec(false);
    //        let uncompressed = "04a598a8030da6d86c6bc7f2f5144ea549d28211ea58faa70ebf4c1e665c1fe9b5204b5d6f84822c307e4b4a7140737aec23fc63b65b35f86a10026dbd2d864e6b";
    //        let uncompressed = hex::decode(uncompressed).unwrap();
    //        assert_eq!(sec, uncompressed);
    //
    //        let sec = point.sec(true);
    //        let compressed = "03a598a8030da6d86c6bc7f2f5144ea549d28211ea58faa70ebf4c1e665c1fe9b5";
    //        let compressed = hex::decode(compressed).unwrap();
    //        assert_eq!(sec, compressed);
    //
    //        // case 3
    //        let coefficient = U512::from(42424242u32);
    //        let point = G.mul(coefficient);
    //
    //        let sec = point.sec(false);
    //        let uncompressed = "04aee2e7d843f7430097859e2bc603abcc3274ff8169c1a469fee0f20614066f8e21ec53f40efac47ac1c5211b2123527e0e9b57ede790c4da1e72c91fb7da54a3";
    //        let uncompressed = hex::decode(uncompressed).unwrap();
    //        assert_eq!(sec, uncompressed);
    //
    //        let sec = point.sec(true);
    //        let compressed = "03aee2e7d843f7430097859e2bc603abcc3274ff8169c1a469fee0f20614066f8e";
    //        let compressed = hex::decode(compressed).unwrap();
    //        assert_eq!(sec, compressed);

}
