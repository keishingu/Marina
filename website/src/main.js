import * as THREE from "three";
import "./style.css";
import { FINGER_PIERS, MAIN_DOCK } from "./harbor-layout.js";

const canvas = document.querySelector("#harbor-canvas");
const hero = document.querySelector(".hero");
const reducedMotion = window.matchMedia("(prefers-reduced-motion: reduce)");

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
  renderer.toneMappingExposure = 1.08;

  const scene = new THREE.Scene();
  scene.background = new THREE.Color(0x06101b);
  scene.fog = new THREE.FogExp2(0x07121e, 0.036);

  const camera = new THREE.PerspectiveCamera(34, 1, 0.1, 80);
  camera.position.set(13.4, 15.8, 15.2);
  const cameraTarget = new THREE.Vector3(1.8, 0, 0);
  camera.lookAt(cameraTarget);

  const seaMaterial = createSeaMaterial();
  const sea = new THREE.Mesh(new THREE.PlaneGeometry(36, 28, 96, 72), seaMaterial);
  sea.rotation.x = -Math.PI / 2;
  sea.position.y = -0.14;
  scene.add(sea);

  const ambient = new THREE.HemisphereLight(0x8fc9ff, 0x02060b, 1.4);
  scene.add(ambient);

  const moon = new THREE.DirectionalLight(0xc6e1ff, 2.4);
  moon.position.set(-8, 16, 10);
  scene.add(moon);

  const dockMaterial = new THREE.MeshStandardMaterial({
    color: 0x44515d,
    roughness: 0.58,
    metalness: 0.25,
  });
  const edgeMaterial = new THREE.MeshStandardMaterial({
    color: 0x17232e,
    roughness: 0.75,
    metalness: 0.08,
  });

  addDock(scene, MAIN_DOCK.position, MAIN_DOCK.size, dockMaterial, edgeMaterial);
  FINGER_PIERS.forEach((pier) => {
    addDock(scene, pier.position, pier.size, dockMaterial, edgeMaterial);
    addBoat(scene, [pier.position[0] + 0.45, 0.42, pier.position[2] - 0.5], pier.port);
  });

  addTerminal(scene);
  const containerShip = addContainerShip(scene);
  addDockLights(scene);

  let animationFrame = 0;
  let visible = true;
  let pageVisible = document.visibilityState === "visible";
  let elapsed = 0;
  let lastTime = performance.now();
  const pointer = new THREE.Vector2();

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
      seaMaterial.uniforms.uTime.value = elapsed;
      containerShip.position.y = 0.34 + Math.sin(elapsed * 0.62) * 0.018;
      containerShip.rotation.z = Math.sin(elapsed * 0.48) * 0.0028;
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
  resize();
  requestRenderLoop();
}

function createSeaMaterial() {
  return new THREE.ShaderMaterial({
    uniforms: {
      uTime: { value: 0 },
      uDeep: { value: new THREE.Color(0x020811) },
      uSurface: { value: new THREE.Color(0x0a3651) },
      uSignal: { value: new THREE.Color(0x168cff) },
    },
    vertexShader: `
      uniform float uTime;
      varying float vWave;
      varying vec3 vWorldPosition;

      void main() {
        vec3 displaced = position;
        float broad = sin(position.x * 0.48 + uTime * 0.42) * 0.11;
        float cross = sin(position.y * 0.74 - uTime * 0.36) * 0.07;
        float detail = sin((position.x + position.y) * 1.7 + uTime * 0.7) * 0.025;
        displaced.z += broad + cross + detail;
        vWave = displaced.z;
        vec4 world = modelMatrix * vec4(displaced, 1.0);
        vWorldPosition = world.xyz;
        gl_Position = projectionMatrix * viewMatrix * world;
      }
    `,
    fragmentShader: `
      uniform float uTime;
      uniform vec3 uDeep;
      uniform vec3 uSurface;
      uniform vec3 uSignal;
      varying float vWave;
      varying vec3 vWorldPosition;

      void main() {
        float wave = smoothstep(-0.14, 0.18, vWave);
        float distanceFade = smoothstep(20.0, 3.0, length(vWorldPosition.xz));
        float rippleA = sin(vWorldPosition.x * 3.1 + vWorldPosition.z * 1.7 + uTime * 0.32);
        float rippleB = sin(vWorldPosition.x * -1.4 + vWorldPosition.z * 4.2 - uTime * 0.24);
        float ripples = (rippleA + rippleB) * 0.5 + 1.0;
        float glint = pow(max(0.0, wave), 6.0) * distanceFade * (0.35 + ripples * 0.18);
        vec3 color = mix(uDeep, uSurface, wave * 0.7 + 0.15);
        color += uSurface * ripples * 0.025;
        color += uSignal * glint * 0.32;
        gl_FragColor = vec4(color, 1.0);
      }
    `,
  });
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

function addBoat(scene, [x, y, z], port) {
  const group = new THREE.Group();
  const hullMaterial = new THREE.MeshStandardMaterial({
    color: 0x142c3f,
    roughness: 0.38,
    metalness: 0.32,
  });
  const cabinMaterial = new THREE.MeshStandardMaterial({
    color: 0xb8c7d2,
    roughness: 0.52,
    metalness: 0.08,
  });
  const windowMaterial = new THREE.MeshStandardMaterial({
    color: 0x7dc7ff,
    emissive: 0x0d5c9c,
    emissiveIntensity: 1.8,
  });

  const hull = new THREE.Mesh(new THREE.BoxGeometry(1.48, 0.28, 0.62), hullMaterial);
  hull.position.y = 0.06;
  group.add(hull);

  const bow = new THREE.Mesh(new THREE.ConeGeometry(0.32, 0.54, 4), hullMaterial);
  bow.rotation.z = -Math.PI / 2;
  bow.position.x = 0.82;
  bow.position.y = 0.06;
  group.add(bow);

  const cabin = new THREE.Mesh(new THREE.BoxGeometry(0.58, 0.34, 0.46), cabinMaterial);
  cabin.position.set(-0.12, 0.34, 0);
  group.add(cabin);

  const window = new THREE.Mesh(new THREE.BoxGeometry(0.28, 0.12, 0.48), windowMaterial);
  window.position.set(0.18, 0.39, 0);
  group.add(window);

  const label = createPortLabel(port);
  label.position.set(0, 0.95, 0);
  group.add(label);

  group.position.set(x, y, z);
  scene.add(group);
}

function createPortLabel(text) {
  const labelCanvas = document.createElement("canvas");
  labelCanvas.width = 320;
  labelCanvas.height = 112;
  const context = labelCanvas.getContext("2d");
  context.clearRect(0, 0, labelCanvas.width, labelCanvas.height);
  context.fillStyle = "rgba(3, 11, 19, 0.86)";
  context.beginPath();
  context.roundRect(42, 14, 236, 84, 24);
  context.fill();
  context.strokeStyle = "rgba(88, 172, 255, 0.55)";
  context.lineWidth = 3;
  context.stroke();
  context.font = "600 48px ui-monospace, SFMono-Regular, Menlo, monospace";
  context.textAlign = "center";
  context.textBaseline = "middle";
  context.fillStyle = "#eef7ff";
  context.fillText(text, 160, 57);

  const texture = new THREE.CanvasTexture(labelCanvas);
  texture.colorSpace = THREE.SRGBColorSpace;
  const material = new THREE.SpriteMaterial({ map: texture, transparent: true, depthWrite: false });
  const sprite = new THREE.Sprite(material);
  sprite.scale.set(1.5, 0.53, 1);
  return sprite;
}

function addTerminal(scene) {
  const buildingMaterial = new THREE.MeshStandardMaterial({
    color: 0x273747,
    roughness: 0.4,
    metalness: 0.28,
  });
  const lightMaterial = new THREE.MeshStandardMaterial({
    color: 0xffddb0,
    emissive: 0xffa94d,
    emissiveIntensity: 2,
  });

  const base = new THREE.Mesh(new THREE.BoxGeometry(1.7, 0.5, 1.7), buildingMaterial);
  base.position.set(1.8, 0.45, -7.1);
  scene.add(base);

  const roof = new THREE.Mesh(new THREE.BoxGeometry(1.34, 0.26, 1.34), buildingMaterial);
  roof.position.set(1.8, 0.85, -7.1);
  scene.add(roof);

  for (const x of [1.38, 1.8, 2.22]) {
    const window = new THREE.Mesh(new THREE.BoxGeometry(0.22, 0.16, 1.38), lightMaterial);
    window.position.set(x, 0.52, -7.1);
    scene.add(window);
  }
}

function addContainerShip(scene) {
  const ship = new THREE.Group();
  const hullMaterial = new THREE.MeshStandardMaterial({
    color: 0x0b3d68,
    roughness: 0.35,
    metalness: 0.42,
  });
  const containerMaterial = new THREE.MeshStandardMaterial({
    color: 0x197bbf,
    roughness: 0.52,
    metalness: 0.18,
  });
  const bridgeMaterial = new THREE.MeshStandardMaterial({
    color: 0xbccbd5,
    roughness: 0.55,
  });

  const hull = new THREE.Mesh(new THREE.BoxGeometry(2.2, 0.58, 8.8), hullMaterial);
  ship.add(hull);

  const deck = new THREE.Mesh(
    new THREE.BoxGeometry(2.04, 0.12, 8.42),
    new THREE.MeshStandardMaterial({ color: 0x8196a6, roughness: 0.68, metalness: 0.12 }),
  );
  deck.position.y = 0.34;
  ship.add(deck);

  for (let row = 0; row < 5; row += 1) {
    for (let column = 0; column < 3; column += 1) {
      const container = new THREE.Mesh(new THREE.BoxGeometry(0.56, 0.36, 1.15), containerMaterial);
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
    new THREE.MeshStandardMaterial({
      color: 0x9fd5ff,
      emissive: 0x276b9b,
      emissiveIntensity: 1.5,
      roughness: 0.3,
    }),
  );
  bridgeWindows.position.set(0, 0.76, -3.55);
  ship.add(bridgeWindows);

  const navigationLightMaterial = new THREE.MeshStandardMaterial({
    color: 0xffdeb0,
    emissive: 0xffa43d,
    emissiveIntensity: 2.8,
  });
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

function addDockLights(scene) {
  const material = new THREE.MeshStandardMaterial({
    color: 0xffe2b4,
    emissive: 0xffa33a,
    emissiveIntensity: 3.2,
  });
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
