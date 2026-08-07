function material(color, roughness, metalness, emissive = 0x000000, emissiveIntensity = 0) {
  return Object.freeze({ color, roughness, metalness, emissive, emissiveIntensity });
}

const LIGHT_THEME = Object.freeze({
  name: "light",
  rendererExposure: 1.06,
  sceneBackground: 0x48bfea,
  fog: Object.freeze({ color: 0x6bc9e8, density: 0.012 }),
  water: Object.freeze({
    sunColor: 0xffffff,
    waterColor: 0x006fc4,
    distortionScale: 2.55,
    glintColor: 0xeafaff,
    glintFalloff: 0.1,
    glintBase: 0.028,
    glintShimmer: 0.078,
  }),
  ambient: Object.freeze({ sky: 0xe6f9ff, ground: 0x075c84, intensity: 1.55 }),
  directional: Object.freeze({ color: 0xfff8df, intensity: 3.25 }),
  label: Object.freeze({
    fill: "rgba(247, 252, 255, 0.94)",
    stroke: "rgba(12, 111, 173, 0.62)",
    text: "#0b4f78",
  }),
  materials: Object.freeze({
    dock: material(0xb8c7ca, 0.72, 0.08),
    dockEdge: material(0x617885, 0.78, 0.04),
    boatHull: material(0xf5fbff, 0.4, 0.12),
    boatCabin: material(0xffffff, 0.48, 0.04),
    boatWindow: material(0x176c99, 0.24, 0.22),
    terminal: material(0xeaf2f4, 0.5, 0.1),
    terminalWindow: material(0x3da6c7, 0.28, 0.18),
    shipHull: material(0x105b8e, 0.35, 0.32),
    containerA: material(0x1689cc, 0.52, 0.18),
    containerB: material(0x27a3d7, 0.52, 0.18),
    containerC: material(0x0d6fa8, 0.52, 0.18),
    shipBridge: material(0xf1f7f8, 0.55, 0),
    shipDeck: material(0xa7b7bc, 0.68, 0.12),
    shipWindow: material(0x9fd5ff, 0.3, 0.18),
    navigationLight: material(0xfff4d8, 0.38, 0),
    dockLight: material(0xf2f7f7, 0.48, 0.16),
  }),
});

const DARK_THEME = Object.freeze({
  name: "dark",
  rendererExposure: 1.08,
  sceneBackground: 0x06101b,
  fog: Object.freeze({ color: 0x07121e, density: 0.036 }),
  water: Object.freeze({
    sunColor: 0xb9dcff,
    waterColor: 0x031827,
    distortionScale: 3.05,
    glintColor: 0x9fd7ff,
    glintFalloff: 0.13,
    glintBase: 0.018,
    glintShimmer: 0.052,
  }),
  ambient: Object.freeze({ sky: 0x8fc9ff, ground: 0x02060b, intensity: 1.4 }),
  directional: Object.freeze({ color: 0xc6e1ff, intensity: 2.4 }),
  label: Object.freeze({
    fill: "rgba(3, 11, 19, 0.86)",
    stroke: "rgba(88, 172, 255, 0.55)",
    text: "#eef7ff",
  }),
  materials: Object.freeze({
    dock: material(0x44515d, 0.58, 0.25),
    dockEdge: material(0x17232e, 0.75, 0.08),
    boatHull: material(0x142c3f, 0.38, 0.32),
    boatCabin: material(0xb8c7d2, 0.52, 0.08),
    boatWindow: material(0x7dc7ff, 0.3, 0.08, 0x0d5c9c, 1.8),
    terminal: material(0x273747, 0.4, 0.28),
    terminalWindow: material(0xffddb0, 0.4, 0, 0xffa94d, 2),
    shipHull: material(0x0b3d68, 0.35, 0.42),
    containerA: material(0x197bbf, 0.52, 0.18),
    containerB: material(0x197bbf, 0.52, 0.18),
    containerC: material(0x197bbf, 0.52, 0.18),
    shipBridge: material(0xbccbd5, 0.55, 0),
    shipDeck: material(0x8196a6, 0.68, 0.12),
    shipWindow: material(0x9fd5ff, 0.3, 0, 0x276b9b, 1.5),
    navigationLight: material(0xffdeb0, 0.4, 0, 0xffa43d, 2.8),
    dockLight: material(0xffe2b4, 0.4, 0, 0xffa33a, 3.2),
  }),
});

export const HARBOR_THEMES = Object.freeze({ light: LIGHT_THEME, dark: DARK_THEME });

export function resolveHarborTheme(prefersDark) {
  if (typeof prefersDark !== "boolean") {
    throw new TypeError("Marina requires a boolean system color-scheme preference.");
  }

  return prefersDark ? HARBOR_THEMES.dark : HARBOR_THEMES.light;
}

export function observeHarborTheme(mediaQuery, applyTheme) {
  if (!mediaQuery || typeof mediaQuery.matches !== "boolean") {
    throw new TypeError("Marina could not read the system color-scheme preference.");
  }

  if (typeof mediaQuery.addEventListener !== "function" || typeof applyTheme !== "function") {
    throw new TypeError("Marina could not observe system color-scheme changes.");
  }

  const handleChange = () => applyTheme(resolveHarborTheme(mediaQuery.matches));
  mediaQuery.addEventListener("change", handleChange);
  handleChange();

  return () => mediaQuery.removeEventListener("change", handleChange);
}
