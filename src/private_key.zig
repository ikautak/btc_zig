const std = @import("std");
const testing = std.testing;

const elliptic_curve = @import("elliptic_curve.zig");
const S256Point = elliptic_curve.S256Point;
const Signature = elliptic_curve.Signature;
const N = elliptic_curve.N;
const G = elliptic_curve.G;
const modpow = elliptic_curve.modpow;
const modmul = elliptic_curve.modmul;

pub fn PrivateKey() type {
    return struct {
        secret: u256,
        point: S256Point(),

        pub fn init(z: u256) @This() {
            return @This(){ .secret = z, .point = G.mul(z) };
        }

        pub fn sign(self: @This(), z: u256) Signature() {
            const rand = std.crypto.random;

            var k = rand.int(u256);
            if (k > N) {
                k -= N;
            }

            const r = G.mul(k).point.x.?.num;
            const k_inv = modpow(u256, k, N - 2, N);
            var s = modmul(u256, z + modmul(u256, r, self.secret, N), k_inv, N);
            if (s > N / 2) {
                s = N - s;
            }
            return Signature().init(r, s);
        }
    };
}

test "private_key_sign" {
    const rand = std.crypto.random;
    const rnd0 = rand.int(u32);
    const pk = PrivateKey().init(rnd0);

    const z = rand.int(u32);
    const sig = pk.sign(z);
    try testing.expect(pk.point.verify(z, sig));
}
