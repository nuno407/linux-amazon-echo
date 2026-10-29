#!/bin/sh
# TAS5805M DSP config blobs (PPC3 output) use register 0xFE as an out-of-band "delay N ms"
# instruction, as Amazon's driver for this amplifier has it: TAS5805M_DELAY (254) in
# sound/soc/codecs/tas5805m.c, tas5805m_apply_seq(), of android_kernel_amazon_mt8163 (see
# ../PROVENANCE.md). Mainline's send_cfg() writes byte pairs verbatim with no such handling, so a
# blob carrying one would land as a real (harmless but useless, and the intended delay lost)
# register write. Teach it the same convention.
set -e
p=${KDIR:-/src/linux-7.2.13}/sound/soc/codecs/tas5805m.c
grep -q 'TAS5805M_CFG_DELAY' $p && exit 0
python3 - "$p" <<'PY'
import sys
p = sys.argv[1]
s = open(p).read()
old = '''static void send_cfg(struct regmap *rm,
		     const uint8_t *s, unsigned int len)
{
	unsigned int i;

	for (i = 0; i + 1 < len; i += 2)
		regmap_write(rm, s[i], s[i + 1]);
}'''
new = '''/* TAS5805M DSP config blobs (TI's PPC3 tool output) use register 0xFE as an out-of-band
 * "delay N milliseconds" instruction -- confirmed against Amazon's downstream driver for this
 * exact chip and speaker config (TAS5805M_DELAY == 254). 0xFE is not a real writable register.
 */
#define TAS5805M_CFG_DELAY 0xfe

static void send_cfg(struct regmap *rm,
		     const uint8_t *s, unsigned int len)
{
	unsigned int i;

	for (i = 0; i + 1 < len; i += 2) {
		if (s[i] == TAS5805M_CFG_DELAY)
			usleep_range(s[i + 1] * 1000, s[i + 1] * 1000 + 200);
		else
			regmap_write(rm, s[i], s[i + 1]);
	}
}'''
assert old in s
open(p, 'w').write(s.replace(old, new, 1))
PY
grep -n "TAS5805M_CFG_DELAY" $p | head -3
