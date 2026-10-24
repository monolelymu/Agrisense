#include "../../firmware/sensor_node_full-20261016T013958Z-1-001/sensor_node_full/auto_capture_timing.h"
#include <cassert>
#include <cstdio>

int main() {
  AutoCaptureTiming timing;
  bool selected[3] = {true, true, false};
  float low[3] = {20, 40, 20}, high[3] = {30, 80, 80};
  float values[3] = {35, 60, NAN};
  auto tick = [&](uint32_t t) { return timing.update(t, values, selected, low, high, 30, 60); };
  timing.reset(0);
  for (uint32_t t = 0; t < 60000; t += 10000) assert(!tick(t));
  assert(tick(60000)); // Sustained condition plus startup cooldown.
  for (uint32_t t = 70000; t < 120000; t += 10000) assert(!tick(t));
  assert(tick(120000)); // One attempt per cooldown during persistent alarm.
  values[0] = 25;
  assert(!tick(130000)); // Recovery resets duration.
  values[0] = 35;
  assert(!tick(180000)); // Missing samples must not count as sustained.
  assert(!tick(190000));
  values[0] = NAN;
  assert(!tick(200000)); // Invalid measurement resets its timer.
  values[0] = 35;
  assert(!tick(210000)); assert(!tick(220000)); assert(!tick(230000));
  assert(tick(240000));
  timing.reset(0);
  values[0] = 30; values[1] = 80; // Exact boundaries are not outside.
  for (uint32_t t = 0; t <= 120000; t += 10000) assert(!tick(t));
  values[0] = 100; // Invalid device values cannot trigger.
  for (uint32_t t = 130000; t <= 240000; t += 10000) assert(!tick(t));
  values[1] = 90; // Humidity alone can trigger (OR).
  assert(!tick(250000)); assert(!tick(260000)); assert(!tick(270000)); assert(tick(280000));
  selected[1] = false;
  values[2] = 0; // Unselected soil cannot trigger.
  for (uint32_t t = 290000; t <= 400000; t += 10000) assert(!tick(t));
  timing.reset(UINT32_MAX - 30000);
  values[0] = 35;
  for (uint32_t elapsed = 0; elapsed < 60000; elapsed += 10000)
    assert(!tick((uint32_t)(UINT32_MAX - 30000 + elapsed)));
  assert(tick((uint32_t)(UINT32_MAX - 30000 + 60000))); // millis rollover.
  std::puts("Automatic capture timing checks passed.");
}
