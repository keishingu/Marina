import {
  DataTexture,
  LinearFilter,
  LinearMipmapLinearFilter,
  RGBAFormat,
  RepeatWrapping,
  UnsignedByteType,
} from "three";

export const WATER_NORMAL_SIZE = 128;

export function createWaterNormalData(size = WATER_NORMAL_SIZE) {
  if (!Number.isInteger(size) || size < 2) {
    throw new RangeError("Water normal texture size must be an integer of at least 2.");
  }

  const data = new Uint8Array(size * size * 4);
  const tau = Math.PI * 2;

  for (let y = 0; y < size; y += 1) {
    const v = y / size;

    for (let x = 0; x < size; x += 1) {
      const u = x / size;
      const phaseA = tau * (u * 11 + v * 7);
      const phaseB = tau * (u * -13 + v * 17 + 0.17);
      const phaseC = tau * (u * 23 + v * -19 + 0.43);
      const slopeX =
        (Math.cos(phaseA) * 0.52 - Math.cos(phaseB) * 0.3 + Math.cos(phaseC) * 0.18) *
        1.5;
      const slopeY =
        (Math.cos(phaseA) * 0.34 + Math.cos(phaseB) * 0.48 - Math.cos(phaseC) * 0.2) *
        1.5;
      const length = Math.hypot(slopeX, slopeY, 1);
      const offset = (y * size + x) * 4;

      data[offset] = Math.round((slopeX / length * 0.5 + 0.5) * 255);
      data[offset + 1] = Math.round((slopeY / length * 0.5 + 0.5) * 255);
      data[offset + 2] = Math.round((1 / length * 0.5 + 0.5) * 255);
      data[offset + 3] = 255;
    }
  }

  return data;
}

export function createWaterNormalTexture(size = WATER_NORMAL_SIZE) {
  const texture = new DataTexture(
    createWaterNormalData(size),
    size,
    size,
    RGBAFormat,
    UnsignedByteType,
  );
  texture.wrapS = RepeatWrapping;
  texture.wrapT = RepeatWrapping;
  texture.magFilter = LinearFilter;
  texture.minFilter = LinearMipmapLinearFilter;
  texture.generateMipmaps = true;
  texture.needsUpdate = true;
  return texture;
}
