import { Color, Vector2 } from "three";

const HARBOR_WAVES = Object.freeze([
  Object.freeze({ direction: [0.89, 0.45], frequency: 0.58, amplitude: 0.064, speed: 0.32 }),
  Object.freeze({ direction: [-0.43, 0.9], frequency: 1.06, amplitude: 0.032, speed: 0.48 }),
  Object.freeze({ direction: [0.23, 0.97], frequency: 1.92, amplitude: 0.014, speed: 0.72 }),
]);

const VERTEX_ANCHOR = "mirrorCoord = modelMatrix * vec4( position, 1.0 );";
const POSITION_ANCHOR = "vec4 mvPosition =  modelViewMatrix * vec4( position, 1.0 );";
const FRAGMENT_ANCHOR = "vec3 outgoingLight = albedo;";

export function sampleHarborWaveHeight(worldX, worldZ, time) {
  const localY = -worldZ;

  return HARBOR_WAVES.reduce((height, wave) => {
    const phase =
      (wave.direction[0] * worldX + wave.direction[1] * localY) * wave.frequency +
      time * wave.speed;
    return height + Math.sin(phase) * wave.amplitude;
  }, 0);
}

export function enhanceOfficialWater(material) {
  if (!material?.vertexShader?.includes(VERTEX_ANCHOR)) {
    throw new Error("The installed Three.js Water vertex shader is not compatible with Marina waves.");
  }

  if (!material.fragmentShader?.includes(FRAGMENT_ANCHOR)) {
    throw new Error("The installed Three.js Water fragment shader is not compatible with Marina glints.");
  }

  material.uniforms.uHarborWaveTime = { value: 0 };
  material.uniforms.uHarborGlintColor = { value: new Color(0xeafaff) };
  material.uniforms.uHarborGlintFalloff = { value: 0.1 };
  material.uniforms.uHarborGlintStrength = { value: new Vector2(0.028, 0.078) };

  material.vertexShader = material.vertexShader
    .replace(
      "varying vec4 worldPosition;",
      `varying vec4 worldPosition;
        varying float vHarborWaveHeight;
        uniform float uHarborWaveTime;`,
    )
    .replace(
      VERTEX_ANCHOR,
      `vec3 displacedPosition = position;
          vec2 harborPoint = position.xy;
          float waveA = dot(vec2(0.89, 0.45), harborPoint) * 0.58 + uHarborWaveTime * 0.32;
          float waveB = dot(vec2(-0.43, 0.90), harborPoint) * 1.06 + uHarborWaveTime * 0.48;
          float waveC = dot(vec2(0.23, 0.97), harborPoint) * 1.92 + uHarborWaveTime * 0.72;
          vHarborWaveHeight = sin(waveA) * 0.064 + sin(waveB) * 0.032 + sin(waveC) * 0.014;
          displacedPosition.xy += vec2(0.89, 0.45) * cos(waveA) * 0.010;
          displacedPosition.xy += vec2(-0.43, 0.90) * cos(waveB) * 0.004;
          displacedPosition.z += vHarborWaveHeight;
          mirrorCoord = modelMatrix * vec4( displacedPosition, 1.0 );`,
    )
    .replace(
      POSITION_ANCHOR,
      "vec4 mvPosition = modelViewMatrix * vec4( displacedPosition, 1.0 );",
    );

  material.fragmentShader = material.fragmentShader
    .replace(
      "uniform vec3 waterColor;",
      `uniform vec3 waterColor;
        uniform vec3 uHarborGlintColor;
        uniform float uHarborGlintFalloff;
        uniform vec2 uHarborGlintStrength;
        uniform float uHarborWaveTime;`,
    )
    .replace(
      "varying vec4 worldPosition;",
      `varying vec4 worldPosition;
        varying float vHarborWaveHeight;`,
    )
    .replace(
      FRAGMENT_ANCHOR,
      `float glintPath = abs(worldPosition.x - worldPosition.z * 0.18 - 8.6);
          float glintBand = exp(-glintPath * glintPath * uHarborGlintFalloff);
          float crest = smoothstep(0.028, 0.098, vHarborWaveHeight);
          float shimmerA = sin(worldPosition.x * 7.4 - worldPosition.z * 4.8 + uHarborWaveTime * 1.35) * 0.5 + 0.5;
          float shimmerB = sin(worldPosition.x * 13.2 + worldPosition.z * 8.7 - uHarborWaveTime * 0.82) * 0.5 + 0.5;
          float shimmer = pow(shimmerA * shimmerB, 1.35);
          vec3 harborGlint = uHarborGlintColor * glintBand * crest * (uHarborGlintStrength.x + shimmer * uHarborGlintStrength.y);
          vec3 outgoingLight = albedo + harborGlint;`,
    );

  if (material.vertexShader.includes(POSITION_ANCHOR)) {
    throw new Error("Marina could not apply displaced positions to the Three.js Water shader.");
  }

  material.needsUpdate = true;
  return material;
}
