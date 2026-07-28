/* SPDX-License-Identifier: GPL-2.0 OR BSD-3-Clause */
/* Compatibility glue for building rtw88 against the LineageOS msm-4.4 tree.
 *
 * This kernel is a hybrid: the core is 4.4, but large parts of the
 * cfg80211/mac80211 stack have been backported from ~4.7.  Version checks in
 * the driver that guard *wireless* API use therefore cannot key off
 * LINUX_VERSION_CODE - it reports 4.4 while the API present is newer.  Use
 * RTW_WIRELESS_VERSION_CODE for those, and keep LINUX_VERSION_CODE for checks
 * against genuinely core APIs (timer_setup(), fsleep(), skb_put_data(), ...)
 * which really are 4.4-era here.
 */

#ifndef __RTW_COMPAT_H_
#define __RTW_COMPAT_H_

#include <linux/version.h>
#include <linux/average.h>
#include <linux/skbuff.h>
#include <linux/string.h>

/* Effective wireless-stack API level of this tree.  Verified against
 * include/net/mac80211.h: ieee80211_ampdu_params and NUM_NL80211_BANDS are
 * present (4.6/4.7), while mgd_prepare_tx() still takes no duration argument
 * and can_aggregate_in_amsdu()/RX_ENC_* are absent (pre-4.18/4.20/4.12).
 */
#define RTW_WIRELESS_VERSION_CODE KERNEL_VERSION(4, 7, 0)

/* The backport is not uniform, so a few individual features have to be probed
 * by name rather than by RTW_WIRELESS_VERSION_CODE.
 *
 * IEEE80211_HW_TX_AMSDU (upstream 4.6) is absent from this tree's hw-flag
 * enum - it ends at IEEE80211_HW_SUPPORTS_AMSDU_IN_AMPDU - and the software
 * A-MSDU aggregation it enables was never backported either.  Leaving it unset
 * only costs some TX throughput on the rtw88 chip's own STA traffic; RX,
 * monitor mode and injection are unaffected.
 */
/* #define RTW_HAS_HW_TX_AMSDU */

/* BSS_CHANGED_MU_GROUPS and ieee80211_bss_conf.mu_group (upstream 4.10) are
 * likewise absent: mac80211 here does not parse VHT Group ID Management
 * frames, so there is nothing to hand to the chip's MU-MIMO group table.
 * Unset, the chip simply never joins a downlink MU-MIMO group as a station.
 * Single-user beamforming, monitor mode and injection are unaffected.
 */
/* #define RTW_HAS_BSS_CHANGED_MU_GROUPS */

/* Upstream 4.10 (commit 9dcadd38faf5, "average: change to declare precision,
 * not factor") redefined DECLARE_EWMA's second argument from the scaling
 * factor to its base-2 logarithm. rtw88 is written against the new form, so
 * on 4.4 DECLARE_EWMA(tp, 10, 2) would ask for a factor of 10 - which is not
 * a power of two, tripping the macro's BUILD_BUG_ON, and would have silently
 * scaled every average by ilog2(10) == 3 instead of 10 had it compiled.
 * The two forms are otherwise identical, so just convert the argument.
 */
#if LINUX_VERSION_CODE < KERNEL_VERSION(4, 10, 0)
#define RTW_DECLARE_EWMA(name, _precision, _weight_rcp)			\
	DECLARE_EWMA(name, 1UL << (_precision), _weight_rcp)
#else
#define RTW_DECLARE_EWMA(name, _precision, _weight_rcp)			\
	DECLARE_EWMA(name, _precision, _weight_rcp)
#endif

/* skb_put_data() appeared in 4.13. */
#if LINUX_VERSION_CODE < KERNEL_VERSION(4, 13, 0)
static inline void *rtw_skb_put_data(struct sk_buff *skb, const void *data,
				     unsigned int len)
{
	void *tmp = skb_put(skb, len);

	memcpy(tmp, data, len);
	return tmp;
}
#define skb_put_data(skb, data, len) rtw_skb_put_data(skb, data, len)
#endif

/* skb_put_zero() appeared in 4.13. */
#if LINUX_VERSION_CODE < KERNEL_VERSION(4, 13, 0)
static inline void *rtw_skb_put_zero(struct sk_buff *skb, unsigned int len)
{
	void *tmp = skb_put(skb, len);

	memset(tmp, 0, len);
	return tmp;
}
#define skb_put_zero(skb, len) rtw_skb_put_zero(skb, len)
#endif

#endif /* __RTW_COMPAT_H_ */
