import * as THREE from "three";
import { Water } from "three/addons/objects/Water.js";
import { describe, expect, test } from "vitest";
import { createWaterNormalTexture } from "./water-normal.js";
import { enhanceOfficialWater, sampleHarborWaveHeight } from "./water-surface.js";

function createOfficialWaterMaterial() {
  const water = new Water(new THREE.PlaneGeometry(4, 4, 4, 4), {
    waterNormals: createWaterNormalTexture(8),
  });
  return water.material;
}

describe("港の水面表現", () => {
  test("波高は穏やかな港の範囲に収まる", () => {
    const samples = [];

    for (let time = 0; time <= 12; time += 0.25) {
      samples.push(sampleHarborWaveHeight(-2.2, 0.2, time));
    }

    expect(Math.max(...samples)).toBeLessThanOrEqual(0.11);
    expect(Math.min(...samples)).toBeGreaterThanOrEqual(-0.11);
  });

  test("時間経過で船が追従できる波高へ変化する", () => {
    expect(sampleHarborWaveHeight(-2.2, 0.2, 0)).not.toBe(
      sampleHarborWaveHeight(-2.2, 0.2, 2),
    );
  });

  test("公式Waterへ立体波とテーマ対応の反射を追加する", () => {
    const material = enhanceOfficialWater(createOfficialWaterMaterial());

    expect(material.uniforms.uHarborWaveTime.value).toBe(0);
    expect(material.uniforms.uHarborGlintFalloff.value).toBe(0.1);
    expect(material.uniforms.uHarborGlintStrength.value.toArray()).toEqual([0.028, 0.078]);
    expect(material.vertexShader).toContain("displacedPosition");
    expect(material.fragmentShader).toContain("harborGlint");
  });

  test("互換性のないWaterシェーダーはエラーにする", () => {
    expect(() =>
      enhanceOfficialWater({ uniforms: {}, vertexShader: "void main() {}", fragmentShader: "" }),
    ).toThrow(/vertex shader/);
  });
});
