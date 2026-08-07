import { describe, expect, test, vi } from "vitest";
import { HARBOR_THEMES, observeHarborTheme, resolveHarborTheme } from "./harbor-theme.js";

describe("港のシステムテーマ", () => {
  test("ライト外観では昼景を返す", () => {
    expect(resolveHarborTheme(false)).toBe(HARBOR_THEMES.light);
  });

  test("ダーク外観では夜景を返す", () => {
    expect(resolveHarborTheme(true)).toBe(HARBOR_THEMES.dark);
  });

  test("外観変更時に現在のテーマを再適用する", () => {
    let changeHandler;
    const mediaQuery = {
      matches: false,
      addEventListener: vi.fn((event, handler) => {
        if (event === "change") changeHandler = handler;
      }),
      removeEventListener: vi.fn(),
    };
    const applyTheme = vi.fn();

    const stopObserving = observeHarborTheme(mediaQuery, applyTheme);
    expect(applyTheme).toHaveBeenLastCalledWith(HARBOR_THEMES.light);

    mediaQuery.matches = true;
    changeHandler();
    expect(applyTheme).toHaveBeenLastCalledWith(HARBOR_THEMES.dark);

    stopObserving();
    expect(mediaQuery.removeEventListener).toHaveBeenCalledWith("change", changeHandler);
  });

  test("外観設定を取得できない場合はエラーにする", () => {
    expect(() => resolveHarborTheme(undefined)).toThrow(/boolean/);
  });
});
