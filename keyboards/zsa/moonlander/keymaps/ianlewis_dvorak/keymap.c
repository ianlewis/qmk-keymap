/*
 * Copyright 2025 Ian Lewis
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *      http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

#include QMK_KEYBOARD_H
#include "version.h"

#define A_CTL MT(MOD_LCTL, KC_ESCAPE)
#define A_MED LT(MEDIA, KC_MINUS)
#define A_LANG LCTL(KC_SPACE)

enum layers {
  BASE,  // default layer
  MEDIA, // media keys
};

// clang-format off
const uint16_t PROGMEM keymaps[][MATRIX_ROWS][MATRIX_COLS] = {

  /* Keymap 0: Base layer
   *
   * ,---------------------------------------------------.         ,---------------------------------------------------.
   * |   =    |   1  |   2   |   3  |   4  |   5  |      |         |      |   6  |   7   |   8  |   9  |   0  |   `    |
   * |--------+------+-------+------+------+-------------|         |------+------+-------+------+------+------+--------|
   * | Tab    |   "  |   ,   |   .  |   P  |   Y  |  [   |         |  ]   |   Y  |   G   |   C  |   R  |   L  |   \    |
   * |--------+------+-------+------+------+------|------|         |------|------+-------+------+------+------+--------|
   * |Ctrl/Esc|   A  |   O   |   E  |   U  |   I  |  (   |         |  )   |   D  |   H   |   T  |   N  |   S  | -/MEDIA|
   * |--------+------+-------+------+------+------|------'         `------|------+-------+------+------+------+--------|
   * | LShift |   ;  |   Q   |   J  |   K  |   X  |                       |   B  |   M   |   W  |   V  |   Z  |   /    |
   * |--------+------+-------+------+------+------'                       `------+-------+------+------+------+--------'
   * |        |      |       | Alt  | LGui |                                     |CtlSPC |      |      |      |        |
   * `-------------------------------------'                                     `-------------------------------------'
   *                                        ,-------------.       ,-------------.
   *                                        |             |       |             |
   *                                 ,------|-------------|       |-------------+------.
   *                                 |      |      |      |       |      |      |      |
   *                                 | Back | Del  |      |       |      | Enter|Space |
   *                                 | Space|      |      |       |      |      |      |
   *                                 `--------------------'       `--------------------'
   */

  [BASE] = LAYOUT(
    KC_EQL,     KC_1,           KC_2,       KC_3,       KC_4,       KC_5,   _______,                _______,    KC_6,       KC_7,   KC_8,       KC_9,       KC_0,       KC_GRV,
    KC_TAB,     KC_QUOT,        KC_COMM,    KC_DOT,     KC_P,       KC_Y,   KC_LBRC,                KC_RBRC,    KC_F,       KC_G,   KC_C,       KC_R,       KC_L,       KC_BSLS,
    A_CTL,      KC_A,           KC_O,       KC_E,       KC_U,       KC_I,   KC_LPRN,                KC_RPRN,    KC_D,       KC_H,   KC_T,       KC_N,       KC_S,       A_MED,
    KC_LSFT,    KC_SCLN,        KC_Q,       KC_J,       KC_K,       KC_X,                                       KC_B,       KC_M,   KC_W,       KC_V,       KC_Z,       KC_SLSH,
    _______,    _______,        _______,    KC_LALT,    KC_LGUI,            _______,                _______,                A_LANG, _______,    _______,    _______,    _______,
                                                        KC_BSPC,    KC_DEL, _______,                _______,    KC_ENT,     KC_SPC
  ),


  /* Keymap 1: Media layer
   *
   * ,-----------------------------------------------------.         ,----------------------------------------------------.
   * |      |  F1  |  F2   |  F3  |  F4  |  F5  |          |         |          |  F6  |  F7   |  F8  |  F9  |  F10 | F11 |
   * |------+------+-------+------+------+-----------------|         |----------+------+-------+------+------+------+-----|
   * |      |      | Home  |   .  | PgUp |      | WWW Back |         | WWW Fwd  |ScrlUp|       | MsUp |      |      |     |
   * |------+------+-------+------+------+------|----------|         |----------|------+-------+------+------+------+-----|
   * |      |      | Left  | Down | Right|      |WWW Search|         | WWW Home |ScrlDn| MsLeft| MsDn |MsRght|      |     |
   * |------+------+-------+------+------+------|----------'         `----------|------+-------+------+------+------+-----|
   * |      |      |  End  | Down | PgDn |      |                               |      |       |      |      |      |     |
   * |------+------+-------+------+------+------'                               `------+-------+------+------+------+-----|
   * |      |      |       |      |      |                                             |       |      |      |      |     |
   * `-----------------------------------'                                             `----------------------------------'
   *                                          ,-------------.       ,-------------.
   *                                          |   VolUp     |       |    Next     |
   *                                   ,------|-------------|       |-------------+------.
   *                                   | Play/|      |      |       |      | Mouse| Mouse|
   *                                   | Pause| Stop | VolDn|       | Prev | Left | Right|
   *                                   |      |      |      |       |      | Click| Click|
   *                                   `--------------------'       `--------------------'
   */

  [MEDIA] = LAYOUT(
    _______,    KC_F1,      KC_F2,      KC_F3,      KC_F4,      KC_F5,      _______,                _______,    KC_F6,          KC_F7,      KC_F8,      KC_F9,          KC_F10,     KC_F11,
    _______,    _______,    KC_HOME,    KC_UP,      KC_PGUP,    _______,    KC_WBAK,                KC_WFWD,    KC_MS_WH_UP,    _______,    KC_MS_UP,   _______,        _______,    _______,
    _______,    _______,    KC_LEFT,    KC_DOWN,    KC_RIGHT,   _______,    KC_WSCH,                KC_WHOM,    KC_MS_WH_DOWN,  KC_MS_LEFT, KC_MS_DOWN, KC_MS_RIGHT,    _______,    _______,
    _______,    _______,    KC_END,     KC_DOWN,    KC_PGDN,    _______,                                        _______,        _______,    _______,    _______,        _______,    _______,
    _______,    _______,    _______,    _______,    _______,                KC_VOLU,                KC_MNXT,                    _______,    _______,    _______,        _______,    _______,
                                                    KC_MPLY,    KC_MSTP,    KC_VOLD,                KC_MPRV,    KC_MS_BTN1,     KC_MS_BTN2
  ),
};
// clang-format on
