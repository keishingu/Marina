import * as THREE from "three";
import { Water } from "three/addons/objects/Water.js";
import "./style.css";
import { FINGER_PIERS, MAIN_DOCK } from "./harbor-layout.js";
import { HARBOR_THEMES, observeHarborTheme } from "./harbor-theme.js";
import { createWaterNormalTexture } from "./water-normal.js";
import { enhanceOfficialWater, sampleHarborWaveHeight } from "./water-surface.js";

const canvas = document.querySelector("#harbor-canvas");
const hero = document.querySelector(".hero");
const reducedMotion = window.matchMedia("(prefers-reduced-motion: reduce)");
const colorScheme = window.matchMedia("(prefers-color-scheme: dark)");

if (canvas && hero) {
  initializeHarbor(canvas, hero);
}

function initializeHarbor(targetCanvas, heroElement) {
  let renderer;

  try {
    renderer = new THREE.WebGLRenderer({
      canvas: targetCanvas,
      antialias: true,
      alpha: false,
      powerPreference: "high-performance",
    });
  } catch (error) {
    heroElement.classList.add("webgl-unavailable");
    console.error("Marina harbor visualization could not start.", error);
    return;
  }

  renderer.outputColorSpace = THREE.SRGBColorSpace;
  renderer.toneMapping = THREE.ACESFilmicToneMapping;
  renderer.toneMappingExposure = HARBOR_THEMES.light.rendererExposure;

  const scene = new THREE.Scene();
  scene.background = new THREE.Color(HARBOR_THEMES.light.sceneBackground);
  scene.fog = new THREE.FogExp2(
    HARBOR_THEMES.light.fog.color,
    HARBOR_THEMES.light.fog.density,
  );
  const themedMaterials = new Map();
  const portLabels = [];

  function createThemedMaterial(role) {
    if (!HARBOR_THEMES.light.materials[role] || !HARBOR_THEMES.dark.materials[role]) {
      throw new Error(`Marina is missing the ${role} material theme.`);
    }

    const material = new THREE.MeshStandardMaterial();
    const materials = themedMaterials.get(role) ?? [];
    materials.push(material);
    themedMaterials.set(role, materials);
    return material;
  }

  const camera = new THREE.PerspectiveCamera(34, 1, 0.1, 80);
  camera.position.set(13.4, 15.8, 15.2);
  const cameraTarget = new THREE.Vector3(1.8, 0, 0);
  camera.lookAt(cameraTarget);

  const reflectionSize = window.matchMedia("(pointer: coarse)").matches ? 256 : 512;
  const sea = new Water(new THREE.PlaneGeometry(36, 28, 96, 72), {
    textureWidth: reflectionSize,
    textureHeight: reflectionSize,
    waterNormals: createWaterNormalTexture(),
    sunDirection: new THREE.Vector3(-8, 16, 10).normalize(),
    sunColor: HARBOR_THEMES.light.water.sunColor,
    waterColor: HARBOR_THEMES.light.water.waterColor,
    distortionScale: HARBOR_THEMES.light.water.distortionScale,
    fog: true,
  });
  enhanceOfficialWater(sea.material);
  sea.rotation.x = -Math.PI / 2;
  sea.position.y = -0.14;
  scene.add(sea);

  const ambient = new THREE.HemisphereLight(
    HARBOR_THEMES.light.ambient.sky,
    HARBOR_THEMES.light.ambient.ground,
    HARBOR_THEMES.light.ambient.intensity,
  );
  scene.add(ambient);

  const directionalLight = new THREE.DirectionalLight(
    HARBOR_THEMES.light.directional.color,
    HARBOR_THEMES.light.directional.intensity,
  );
  directionalLight.position.set(-8, 16, 10);
  scene.add(directionalLight);

  const dockMaterial = createThemedMaterial("dock");
  const edgeMaterial = createThemedMaterial("dockEdge");
  const boatMaterials = {
    hull: createThemedMaterial("boatHull"),
    cabin: createThemedMaterial("boatCabin"),
    window: createThemedMaterial("boatWindow"),
  };

  addDock(scene, MAIN_DOCK.position, MAIN_DOCK.size, dockMaterial, edgeMaterial);
  FINGER_PIERS.forEach((pier) => {
    addDock(scene, pier.position, pier.size, dockMaterial, edgeMaterial);
    const label = addBoat(
      scene,
      [pier.position[0] + 0.45, 0.42, pier.position[2] - 0.5],
      pier.port,
      boatMaterials,
    );
    portLabels.push(label);
  });

  addTerminal(scene, {
    building: createThemedMaterial("terminal"),
    window: createThemedMaterial("terminalWindow"),
  });
  const containerShip = addContainerShip(scene, createThemedMaterial);
  addDockLights(scene, createThemedMaterial("dockLight"));

  let animationFrame = 0;
  let visible = true;
  let pageVisible = document.visibilityState === "visible";
  let elapsed = 0;
  let lastTime = performance.now();
  const pointer = new THREE.Vector2();

  function applyTheme(theme) {
    renderer.toneMappingExposure = theme.rendererExposure;
    scene.background.setHex(theme.sceneBackground);
    scene.fog.color.setHex(theme.fog.color);
    scene.fog.density = theme.fog.density;

    sea.material.uniforms.sunColor.value.setHex(theme.water.sunColor);
    sea.material.uniforms.waterColor.value.setHex(theme.water.waterColor);
    sea.material.uniforms.distortionScale.value = theme.water.distortionScale;
    sea.material.uniforms.uHarborGlintColor.value.setHex(theme.water.glintColor);
    sea.material.uniforms.uHarborGlintFalloff.value = theme.water.glintFalloff;
    sea.material.uniforms.uHarborGlintStrength.value.set(
      theme.water.glintBase,
      theme.water.glintShimmer,
    );

    ambient.color.setHex(theme.ambient.sky);
    ambient.groundColor.setHex(theme.ambient.ground);
    ambient.intensity = theme.ambient.intensity;
    directionalLight.color.setHex(theme.directional.color);
    directionalLight.intensity = theme.directional.intensity;

    for (const [role, materials] of themedMaterials) {
      const appearance = theme.materials[role];
      if (!appearance) {
        throw new Error(`Marina could not apply the ${role} material theme.`);
      }
      materials.forEach((material) => applyMaterialAppearance(material, appearance));
    }

    portLabels.forEach((label) => label.userData.applyTheme(theme.label));
    requestRenderLoop();
  }

  function resize() {
    const rect = heroElement.getBoundingClientRect();
    const width = Math.max(1, rect.width);
    const height = Math.max(1, rect.height);
    renderer.setPixelRatio(Math.min(window.devicePixelRatio || 1, 1.5));
    renderer.setSize(width, height, false);
    camera.aspect = width / height;
    camera.updateProjectionMatrix();
    render();
  }

  function render() {
    renderer.render(scene, camera);
  }

  function animate(now) {
    animationFrame = 0;
    const delta = Math.min((now - lastTime) / 1000, 0.05);
    lastTime = now;
    elapsed += delta;

    if (!reducedMotion.matches) {
      sea.material.uniforms.time.value = elapsed * 0.72;
      sea.material.uniforms.uHarborWaveTime.value = elapsed;
      const shipX = containerShip.position.x;
      const shipZ = containerShip.position.z;
      const shipWave = sampleHarborWaveHeight(shipX, shipZ, elapsed);
      const portWave = sampleHarborWaveHeight(shipX - 1, shipZ, elapsed);
      const starboardWave = sampleHarborWaveHeight(shipX + 1, shipZ, elapsed);
      containerShip.position.y = 0.34 + shipWave * 0.48;
      containerShip.rotation.z = (starboardWave - portWave) * 0.085;
      const targetX = 13.4 + pointer.x * 0.42;
      const targetZ = 15.2 - pointer.y * 0.28;
      camera.position.x += (targetX - camera.position.x) * 0.025;
      camera.position.z += (targetZ - camera.position.z) * 0.025;
      camera.lookAt(cameraTarget);
    }

    render();

    if (visible && pageVisible && !reducedMotion.matches) {
      animationFrame = requestAnimationFrame(animate);
    }
  }

  function requestRenderLoop() {
    if (animationFrame || !visible || !pageVisible || reducedMotion.matches) {
      render();
      return;
    }
    lastTime = performance.now();
    animationFrame = requestAnimationFrame(animate);
  }

  const visibilityObserver = new IntersectionObserver(
    ([entry]) => {
      visible = entry.isIntersecting;
      if (!visible && animationFrame) {
        cancelAnimationFrame(animationFrame);
        animationFrame = 0;
      }
      requestRenderLoop();
    },
    { threshold: 0.02 },
  );
  visibilityObserver.observe(heroElement);

  const resizeObserver = new ResizeObserver(resize);
  resizeObserver.observe(heroElement);

  document.addEventListener("visibilitychange", () => {
    pageVisible = document.visibilityState === "visible";
    if (!pageVisible && animationFrame) {
      cancelAnimationFrame(animationFrame);
      animationFrame = 0;
    }
    requestRenderLoop();
  });

  heroElement.addEventListener(
    "pointermove",
    (event) => {
      const rect = heroElement.getBoundingClientRect();
      pointer.x = (event.clientX - rect.left) / rect.width - 0.5;
      pointer.y = (event.clientY - rect.top) / rect.height - 0.5;
    },
    { passive: true },
  );

  reducedMotion.addEventListener("change", requestRenderLoop);
  observeHarborTheme(colorScheme, applyTheme);
  resize();
  requestRenderLoop();
}

function applyMaterialAppearance(material, appearance) {
  material.color.setHex(appearance.color);
  material.emissive.setHex(appearance.emissive);
  material.emissiveIntensity = appearance.emissiveIntensity;
  material.roughness = appearance.roughness;
  material.metalness = appearance.metalness;
  material.needsUpdate = true;
}

function addDock(scene, position, size, material, edgeMaterial) {
  const edge = new THREE.Mesh(
    new THREE.BoxGeometry(size[0] + 0.12, size[1] + 0.08, size[2] + 0.12),
    edgeMaterial,
  );
  edge.position.set(position[0], position[1] - 0.035, position[2]);
  scene.add(edge);

  const dock = new THREE.Mesh(new THREE.BoxGeometry(...size), material);
  dock.position.set(...position);
  scene.add(dock);
}

function addBoat(scene, [x, y, z], port, materials) {
  const group = new THREE.Group();

  const hull = new THREE.Mesh(new THREE.BoxGeometry(1.48, 0.28, 0.62), materials.hull);
  hull.position.y = 0.06;
  group.add(hull);

  const bow = new THREE.Mesh(new THREE.ConeGeometry(0.32, 0.54, 4), materials.hull);
  bow.rotation.z = -Math.PI / 2;
  bow.position.x = 0.82;
  bow.position.y = 0.06;
  group.add(bow);

  const cabin = new THREE.Mesh(new THREE.BoxGeometry(0.58, 0.34, 0.46), materials.cabin);
  cabin.position.set(-0.12, 0.34, 0);
  group.add(cabin);

  const window = new THREE.Mesh(new THREE.BoxGeometry(0.28, 0.12, 0.48), materials.window);
  window.position.set(0.18, 0.39, 0);
  group.add(window);

  const label = createPortLabel(port);
  label.position.set(0, 0.95, 0);
  group.add(label);

  group.position.set(x, y, z);
  scene.add(group);
  return label;
}

function createPortLabel(text) {
  const labelCanvas = document.createElement("canvas");
  labelCanvas.width = 320;
  labelCanvas.height = 112;
  const context = labelCanvas.getContext("2d");
  if (!context) {
    throw new Error("Marina could not create the port label canvas.");
  }

  const texture = new THREE.CanvasTexture(labelCanvas);
  texture.colorSpace = THREE.SRGBColorSpace;
  const material = new THREE.SpriteMaterial({ map: texture, transparent: true, depthWrite: false });
  const sprite = new THREE.Sprite(material);
  sprite.scale.set(1.5, 0.53, 1);
  sprite.userData.applyTheme = (appearance) => {
    context.clearRect(0, 0, labelCanvas.width, labelCanvas.height);
    context.fillStyle = appearance.fill;
    context.beginPath();
    context.roundRect(42, 14, 236, 84, 24);
    context.fill();
    context.strokeStyle = appearance.stroke;
    context.lineWidth = 3;
    context.stroke();
    context.font = "600 48px ui-monospace, SFMono-Regular, Menlo, monospace";
    context.textAlign = "center";
    context.textBaseline = "middle";
    context.fillStyle = appearance.text;
    context.fillText(text, 160, 57);
    texture.needsUpdate = true;
  };
  return sprite;
}

function addTerminal(scene, materials) {
  const base = new THREE.Mesh(new THREE.BoxGeometry(1.7, 0.5, 1.7), materials.building);
  base.position.set(1.8, 0.45, -7.1);
  scene.add(base);

  const roof = new THREE.Mesh(new THREE.BoxGeometry(1.34, 0.26, 1.34), materials.building);
  roof.position.set(1.8, 0.85, -7.1);
  scene.add(roof);

  for (const x of [1.38, 1.8, 2.22]) {
    const window = new THREE.Mesh(new THREE.BoxGeometry(0.22, 0.16, 1.38), materials.window);
    window.position.set(x, 0.52, -7.1);
    scene.add(window);
  }
}

function addContainerShip(scene, createThemedMaterial) {
  const ship = new THREE.Group();
  const hullMaterial = createThemedMaterial("shipHull");
  const containerMaterials = ["containerA", "containerB", "containerC"].map(
    createThemedMaterial,
  );
  const bridgeMaterial = createThemedMaterial("shipBridge");

  const hull = new THREE.Mesh(new THREE.BoxGeometry(2.2, 0.58, 8.8), hullMaterial);
  ship.add(hull);

  const deck = new THREE.Mesh(
    new THREE.BoxGeometry(2.04, 0.12, 8.42),
    createThemedMaterial("shipDeck"),
  );
  deck.position.y = 0.34;
  ship.add(deck);

  for (let row = 0; row < 5; row += 1) {
    for (let column = 0; column < 3; column += 1) {
      const container = new THREE.Mesh(
        new THREE.BoxGeometry(0.56, 0.36, 1.15),
        containerMaterials[(row + column) % containerMaterials.length],
      );
      container.position.set((column - 1) * 0.62, 0.48, -1.8 + row * 1.23);
      ship.add(container);
    }
  }

  const bow = new THREE.Mesh(new THREE.ConeGeometry(1.05, 1.55, 4), hullMaterial);
  bow.rotation.x = Math.PI / 2;
  bow.rotation.z = Math.PI / 4;
  bow.position.set(0, 0, 5.1);
  ship.add(bow);

  const bridge = new THREE.Mesh(new THREE.BoxGeometry(1.5, 0.86, 1.02), bridgeMaterial);
  bridge.position.set(0, 0.64, -3.55);
  ship.add(bridge);

  const bridgeWindows = new THREE.Mesh(
    new THREE.BoxGeometry(1.54, 0.18, 1.06),
    createThemedMaterial("shipWindow"),
  );
  bridgeWindows.position.set(0, 0.76, -3.55);
  ship.add(bridgeWindows);

  const navigationLightMaterial = createThemedMaterial("navigationLight");
  const navigationLightGeometry = new THREE.SphereGeometry(0.045, 8, 8);
  for (let z = -3.8; z <= 4.1; z += 1.12) {
    for (const x of [-1.04, 1.04]) {
      const light = new THREE.Mesh(navigationLightGeometry, navigationLightMaterial);
      light.position.set(x, 0.48, z);
      ship.add(light);
    }
  }

  ship.position.set(-2.2, 0.34, 0.2);
  scene.add(ship);
  return ship;
}

function addDockLights(scene, material) {
  const geometry = new THREE.SphereGeometry(0.055, 8, 8);

  for (let z = -6.5; z <= 6.5; z += 1.1) {
    for (const x of [1.43, 2.17]) {
      const light = new THREE.Mesh(geometry, material);
      light.position.set(x, 0.36, z);
      scene.add(light);
    }
  }

  FINGER_PIERS.forEach((pier) => {
    for (let x = 2.35; x <= 7.05; x += 1.18) {
      const light = new THREE.Mesh(geometry, material);
      light.position.set(x, 0.3, pier.position[2]);
      scene.add(light);
    }
  });
}
