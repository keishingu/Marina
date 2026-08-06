import { describe, expect, test } from "vitest";
import { FINGER_PIERS, MAIN_DOCK, PORTS, piersAreOrthogonal } from "./harbor-layout.js";

describe("港湾レイアウト", () => {
  test("係留桟橋は主桟橋に対して直角に接続される", () => {
    expect(piersAreOrthogonal()).toBe(true);
  });

  test("各ポート番号に対応する係留桟橋が存在する", () => {
    expect(FINGER_PIERS.map((pier) => pier.port)).toEqual(PORTS);
  });

  test("すべての係留桟橋は主桟橋の右側へ伸びる", () => {
    const mainDockRightEdge = MAIN_DOCK.position[0] + MAIN_DOCK.size[0] / 2;
    expect(
      FINGER_PIERS.every(
        (pier) => pier.position[0] - pier.size[0] / 2 <= mainDockRightEdge + 0.2,
      ),
    ).toBe(true);
  });
});
