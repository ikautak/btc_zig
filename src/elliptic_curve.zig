const std = @import("std");
const testing = std.testing;
const FieldElement = @import("field_element.zig");
const Point = @import("point.zig");

pub fn modpow(comptime T: type, x: T, exp: T, m: T) T {
    var result: T = 1;
    while (exp > 0) {
        if (exp % 2 == 1) {
            result = (result * x) % m;
        }
        x = (x * x) % m;
        exp /= 2;
    }

    return result;
}

const A: u256 = 0;
const B: u256 = 7;
const P: u256 = 0xfffffffffffffffffffffffffffffffffffffffffffffffffffffffefffffc2f;
const N: u256 = 0xfffffffffffffffffffffffffffffffebaaedce6af48a03bbfd25e8cd0364141;

const S256Field = FieldElement.FieldElement(u256);
//pub fn S256Field() type {
//    return struct {
//        field: FieldElement.FieldElement(u256),
//
//        pub fn sqrt(self: @This()) @This() {
//            const p = @divTrunc(P + 1, 4);
//            return self.field.pow(p);
//        }
//    };
//}

pub fn S256Point() type {
    return struct {
        point: Point.Point(S256Field),

        pub fn init(x: u256, y: u256) @This() {
            const a = S256Field.init(A, P);
            const b = S256Field.init(B, P);
            const x_ = S256Field.init(x, P);
            const y_ = S256Field.init(y, P);
            return @This(){ .point = Point.Point(S256Field).init(x_, y_, a, b) };
        }

        pub fn mul(self: @This(), coefficient: u256) @This() {
            const coef = coefficient % N;
            return @This(){ .point = self.point.rmul(coef) };
        }

        pub fn verify(self: @This(), z: u256, sig: Signature) bool {
            const s_inv = modpow(sig.s, N - 2, N);
            const u = (z * s_inv) % N;
            const v = (sig.r * s_inv) % N;
            const total = G.mul(u).point.add(self.mul(v).point);
            return total.x == sig.r;
        }

        //pub fn sec(self: @This(), compressed: bool) {
        //
        //}
    };
}

const GX: u256 = 0x79be667ef9dcbbac55a06295ce870b07029bfcdb2dce28d959f2815b16f81798;
const GY: u256 = 0x483ada7726a3c4655da4fbfc0e1108a8fd17b448a68554199c47d08ffb10d4b8;
const G = S256Point().init(GX, GY);

pub fn Signature() type {
    return struct {
        r: u256,
        s: u256,

        pub fn init(r: u256, s: u256) @This() {
            return .{ .r = r, .s = s };
        }
    };
}
