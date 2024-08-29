const std = @import("std");
const FieldElement = @import("field_element");
const Point = @import("point");

const A: u256 = 0;
const B: u256 = 7;
const P: u256 = 0xfffffffffffffffffffffffffffffffffffffffffffffffffffffffefffffc2f;
const N: u256 = 0xfffffffffffffffffffffffffffffffebaaedce6af48a03bbfd25e8cd0364141;

pub fn S256Field() type {
    return struct {
        field: FieldElement(u256),

        pub fn sqrt(self: @This()) @This() {
            const p = @divTrunc(P + 1, 4);
            return self.field.pow(p);
        }
    };
}

pub fn S256Point() type {
    return struct {
        point: Point(S256Field()),

        pub fn init(x: u256, y: u256) @This() {
            const a = S256Field().init(A, P);
            const b = S256Field().init(B, P);
            const x_ = S256Field().init(x, P);
            const y_ = S256Field().init(y, P);
            return .{ .point = Point(S256Field()).init(?x_, ?y_, a, b) };
        }

        pub fn mul(self: @This(), coefficient: u256) @This() {
            const coef = coefficient % N;
            return .{ .point = self.point.rmul(coef) };
        }

        //pub fn verify(self: @This(), z: u256, sig: Signature) bool {
        //
        //}

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
