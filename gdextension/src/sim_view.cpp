// Ground sampling and line of sight for the general's view. Ports of
// HeightField.height_at, Visibility.visibility_factor and Woods.depth_along;
// doubles inside, like GDScript's float, so the two agree to rounding.
#include "sim_view.h"

#include <algorithm>
#include <cmath>

namespace legatus {

namespace {

struct Vec3d {
	double x, y, z;
};

Vec3d lerp3(const Vec3d &p_a, const Vec3d &p_b, double p_t) {
	return { p_a.x + (p_b.x - p_a.x) * p_t, p_a.y + (p_b.y - p_a.y) * p_t,
		p_a.z + (p_b.z - p_a.z) * p_t };
}

double dist3(const Vec3d &p_a, const Vec3d &p_b) {
	const double dx = p_b.x - p_a.x;
	const double dy = p_b.y - p_a.y;
	const double dz = p_b.z - p_a.z;
	return std::sqrt(dx * dx + dy * dy + dz * dz);
}

double ground(const GroundField &p_g, double p_x, double p_z) {
	return p_g.empty() ? 0.0 : double(p_g.height_at(float(p_x), float(p_z)));
}

// Visibility.terrain_blocks: ground (plus the earth's bulge) above the line.
bool terrain_blocks(const GroundField &p_g, const SightParams &p_s, Vec3d p_eye, Vec3d p_pt) {
	if (p_g.empty()) {
		return false;
	}
	const double length = dist3(p_eye, p_pt);
	const double usable = length - p_s.end_clearance;
	if (usable <= 0.0) {
		return false;
	}
	const double step = double(p_g.spacing) * 0.5;
	const int32_t samples = int32_t(usable / step);
	const double two_r = 2.0 * p_s.earth_radius;
	for (int32_t i = 1; i <= samples; i++) {
		const double t = double(i) * step / length;
		const Vec3d p = lerp3(p_eye, p_pt, t);
		const double bulge = t * (1.0 - t) * length * length / two_r;
		if (ground(p_g, p.x, p.z) + bulge > p.y + p_s.terrain_tolerance) {
			return true;
		}
	}
	return false;
}

double clearance(const GroundField &p_g, const SightParams &p_s, Vec3d p_eye, Vec3d p_pt,
		double p_t) {
	const Vec3d p = lerp3(p_eye, p_pt, p_t);
	return p.y - (ground(p_g, p.x, p.z) + p_s.canopy_height);
}

// Woods.depth_along: metres of forest below the canopy along the sight line.
double woods_depth(const GroundField &p_g, const SightParams &p_s, Vec3d p_eye, Vec3d p_pt) {
	double total = 0.0;
	const double dx = p_pt.x - p_eye.x;
	const double dz = p_pt.z - p_eye.z;
	const double qa = dx * dx + dz * dz;
	if (qa < 1e-6) {
		return 0.0;
	}
	for (size_t i = 0; i < p_s.woods_r.size(); i++) {
		const double fx = p_eye.x - p_s.woods_x[i];
		const double fz = p_eye.z - p_s.woods_z[i];
		const double r = p_s.woods_r[i];
		const double qb = 2.0 * (fx * dx + fz * dz);
		const double disc = qb * qb - 4.0 * qa * (fx * fx + fz * fz - r * r);
		if (disc <= 0.0) {
			continue;
		}
		const double root = std::sqrt(disc);
		const double t0 = std::clamp((-qb - root) / (2.0 * qa), 0.0, 1.0);
		const double t1 = std::clamp((-qb + root) / (2.0 * qa), 0.0, 1.0);
		if (t1 <= t0) {
			continue;
		}
		const double c0 = clearance(p_g, p_s, p_eye, p_pt, t0);
		const double c1 = clearance(p_g, p_s, p_eye, p_pt, t1);
		double under = 0.0;
		if (c0 < 0.0 && c1 < 0.0) {
			under = t1 - t0;
		} else if (c0 < 0.0 || c1 < 0.0) {
			under = (t1 - t0) * -(c0 < 0.0 ? c0 : c1) / std::abs(c1 - c0);
		}
		total += under * dist3(p_eye, p_pt);
	}
	return total;
}

} // namespace

float GroundField::height_at(float p_x, float p_z) const {
	if (empty()) {
		return 0.0f;
	}
	const double top = double(resolution - 1);
	const double gx = std::clamp((double(p_x) - origin_x) / spacing, 0.0, top);
	const double gz = std::clamp((double(p_z) - origin_z) / spacing, 0.0, top);
	const int32_t x0 = std::min(int32_t(gx), resolution - 2);
	const int32_t z0 = std::min(int32_t(gz), resolution - 2);
	const double fx = gx - double(x0);
	const double fz = gz - double(z0);
	const float *row = heights.data() + size_t(z0) * size_t(resolution) + size_t(x0);
	const double r0 = row[0] + (double(row[1]) - row[0]) * fx;
	const double r1 = row[resolution] + (double(row[resolution + 1]) - row[resolution]) * fx;
	return float(r0 + (r1 - r0) * fz);
}

bool SightTiles::is_visible(float p_x, float p_z) const {
	if (!active()) {
		return true;
	}
	const int32_t c = int32_t(std::floor((p_x - origin_x) / tile_size));
	const int32_t r = int32_t(std::floor((p_z - origin_z) / tile_size));
	if (c < 0 || r < 0 || c >= cols || r >= rows) {
		return true;
	}
	return visible[size_t(r) * size_t(cols) + size_t(c)] != 0;
}

float sight_factor(const GroundField &p_ground, const SightParams &p_sight, Vec3f p_eye,
		Vec3f p_point) {
	const Vec3d eye = { p_eye.x, p_eye.y, p_eye.z };
	const Vec3d pt = { p_point.x, p_point.y, p_point.z };
	const double distance = dist3(eye, pt);
	if (distance > p_sight.max_distance || terrain_blocks(p_ground, p_sight, eye, pt)) {
		return 0.0f;
	}
	const double span = double(p_sight.max_distance) - p_sight.haze_start;
	double factor = std::clamp(1.0 - (distance - p_sight.haze_start) / span, 0.0, 1.0);
	if (!p_sight.woods_r.empty()) {
		factor *= std::exp(-woods_depth(p_ground, p_sight, eye, pt) / p_sight.woods_extinction);
	}
	const double dust = std::clamp(double(p_sight.dust_density), 0.0, 1.0);
	factor *= std::exp(-dust * distance / p_sight.dust_extinction);
	return float(factor);
}

} // namespace legatus
