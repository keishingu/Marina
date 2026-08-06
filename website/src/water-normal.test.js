import { describe, expect, test } from "vitest";
import { createWaterNormalData, createWaterNormalTexture } from "./water-normal.js";

describe("水面法線テクスチャ", () => {
  test("指定サイズのRGBAデータを生成する", () => {
    const data = createWaterNormalData(16);

    expect(data).toHaveLength(16 * 16 * 4);
    expect(data.every((value, index) => index % 4 !== 3 || value === 255)).toBe(true);
  });

  test("水面に変化を与える複数の法線を含む", () => {
    const data = createWaterNormalData(16);
    const normals = new Set();

    for (let index = 0; index < data.length; index += 4) {
      normals.add(`${data[index]},${data[index + 1]},${data[index + 2]}`);
    }

    expect(normals.size).toBeGreaterThan(32);
  });

  test("公式Waterで繰り返し利用できるテクスチャを生成する", () => {
    const texture = createWaterNormalTexture(8);

    expect(texture.image.width).toBe(8);
    expect(texture.image.height).toBe(8);
    expect(texture.wrapS).toBe(texture.wrapT);
    expect(texture.generateMipmaps).toBe(true);
  });

  test("不正なテクスチャサイズはエラーにする", () => {
    expect(() => createWaterNormalData(1)).toThrow(RangeError);
    expect(() => createWaterNormalData(4.5)).toThrow(RangeError);
  });
});
