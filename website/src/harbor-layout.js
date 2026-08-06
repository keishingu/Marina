export const PORTS = [":3000", ":4000", ":5173", ":5432", ":6379", ":8080"];

export const MAIN_DOCK = Object.freeze({
  position: [1.8, 0.12, 0],
  size: [0.72, 0.24, 14.5],
  direction: [0, 1],
});

export const FINGER_PIERS = Object.freeze(
  [-5.4, -3.2, -1, 1.2, 3.4, 5.6].map((z, index) => ({
    port: PORTS[index],
    position: [4.7, 0.1, z],
    size: [5.2, 0.2, 0.32],
    direction: [1, 0],
  })),
);

export function dot2D([ax, az], [bx, bz]) {
  return ax * bx + az * bz;
}

export function piersAreOrthogonal(mainDock = MAIN_DOCK, fingerPiers = FINGER_PIERS) {
  return fingerPiers.every((pier) => dot2D(mainDock.direction, pier.direction) === 0);
}
