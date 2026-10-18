import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';

import '../premium/premium_controller.dart';
import '../state/language_controller.dart';
import 'app_language.dart';

/// UI text for Premium. Same rule as [AppStrings]: each language is a
/// subclass, so a missing translation is a compile error.
///
/// In `build` use `context.premium`; in callbacks `context.readPremium`.
abstract class PremiumStrings {
  const PremiumStrings();

  static PremiumStrings of(AppLanguage language) => switch (language) {
        AppLanguage.en => const EnPremiumStrings(),
        AppLanguage.hi => const HiPremiumStrings(),
      };

  String get premium;
  String get premiumTagline;
  String get oneTime;
  String get whatYouGet;
  String get benefitPyqs;
  String get benefitPyqsBody;
  String get benefitAnalysis;
  String get benefitAnalysisBody;
  String get benefitRevisionSets;
  String get benefitMockTests;
  String get comingSoonIncluded;
  String get alwaysFree;
  String get alwaysFreeBody;
  String buyFor(String price);
  String get restore;
  String get active;
  String get activeBody;
  String get pendingTitle;
  String get pendingBody;
  String get linkedToPlay;
  String get priceNote;
  String notice(PremiumNotice n);
  String unavailable(PremiumUnavailable u);

  // Locked features
  String get lockedTitle;
  String get lockedPyqs;
  String get lockedAnalysis;
  String unlockFor(String price);
  String get seePremium;
}

class EnPremiumStrings extends PremiumStrings {
  const EnPremiumStrings();

  @override
  String get premium => 'Premium';
  @override
  String get premiumTagline => 'Board-exam practice with official past papers and deeper progress insights.';
  @override
  String get oneTime => 'One-time purchase · no subscription';
  @override
  String get whatYouGet => 'What you get';
  @override
  String get benefitPyqs => 'Chapter-wise PYQs';
  @override
  String get benefitPyqsBody => 'Previous-year board questions by chapter, year and marks, with checked model answers, plus PYQ practice.';
  @override
  String get benefitAnalysis => 'Detailed performance analysis';
  @override
  String get benefitAnalysisBody => 'Accuracy breakdown and chapter-wise progress for every class.';
  @override
  String get benefitRevisionSets => 'Advanced revision sets';
  @override
  String get benefitMockTests => 'Extra mock tests and practice questions';
  @override
  String get comingSoonIncluded => 'Coming soon · included at no extra cost';
  @override
  String get alwaysFree => 'Always free';
  @override
  String get alwaysFreeBody => 'Notes, topics, virtual labs, practicals, practice questions, mistake revision, focus mode, your notes and basic progress.';
  @override
  String buyFor(String price) => 'Buy Premium · $price';
  @override
  String get restore => 'Restore purchase';
  @override
  String get active => 'Premium is active';
  @override
  String get activeBody => 'Thank you! Everything in Premium is unlocked.';
  @override
  String get pendingTitle => 'Payment pending';
  @override
  String get pendingBody => 'Premium unlocks automatically once Google Play confirms your payment.';
  @override
  String get linkedToPlay => 'Premium is linked to your Google Play account. Use Restore purchase on a new phone or after reinstalling.';
  @override
  String get priceNote => 'Payment is handled by Google Play. The price shown in the Google Play sheet is final.';
  @override
  String notice(PremiumNotice n) => switch (n) {
        PremiumNotice.purchased => 'Purchase confirmed. Premium is unlocked!',
        PremiumNotice.restored => 'Purchase restored. Premium is unlocked.',
        PremiumNotice.nothingToRestore => 'No Premium purchase found on this Google Play account.',
        PremiumNotice.pending => 'Your payment is pending. Premium unlocks once it is confirmed.',
        PremiumNotice.cancelled => 'Purchase cancelled. You were not charged.',
        PremiumNotice.failed => 'Purchase could not be completed. Please try again. If you already bought Premium, tap Restore purchase.',
        PremiumNotice.verifyFailed => 'Payment received but not confirmed yet. Check your internet and tap Restore purchase.',
        PremiumNotice.rejected => 'This purchase could not be verified with Google Play.',
        PremiumNotice.revoked => 'Premium was removed because the purchase was refunded or cancelled.',
      };
  @override
  String unavailable(PremiumUnavailable u) => switch (u) {
        PremiumUnavailable.notConfigured => 'Purchases are not set up in this version of the app.',
        PremiumUnavailable.storeUnavailable => 'Google Play is not available. Install the app from Google Play and check your internet.',
        PremiumUnavailable.productUnavailable => 'Premium is not available to buy right now. Please try again later.',
      };
  @override
  String get lockedTitle => 'Premium feature';
  @override
  String get lockedPyqs => 'Previous-year questions with answers are part of Premium.';
  @override
  String get lockedAnalysis => 'Accuracy breakdown and chapter-wise progress are part of Premium.';
  @override
  String unlockFor(String price) => 'Unlock for $price';
  @override
  String get seePremium => 'See Premium';
}

class HiPremiumStrings extends PremiumStrings {
  const HiPremiumStrings();

  @override
  String get premium => 'प्रीमियम';
  @override
  String get premiumTagline => 'आधिकारिक पिछले वर्षों के प्रश्न-पत्रों से बोर्ड परीक्षा की तैयारी और प्रगति का गहरा विश्लेषण।';
  @override
  String get oneTime => 'एक बार की खरीद · कोई सब्सक्रिप्शन नहीं';
  @override
  String get whatYouGet => 'आपको क्या मिलेगा';
  @override
  String get benefitPyqs => 'अध्याय-वार PYQ';
  @override
  String get benefitPyqsBody => 'अध्याय, वर्ष और अंकों के अनुसार पिछले वर्षों के बोर्ड प्रश्न, जाँचे गए मॉडल उत्तरों के साथ, और PYQ अभ्यास।';
  @override
  String get benefitAnalysis => 'विस्तृत प्रदर्शन विश्लेषण';
  @override
  String get benefitAnalysisBody => 'हर कक्षा के लिए सटीकता का विवरण और अध्याय-वार प्रगति।';
  @override
  String get benefitRevisionSets => 'एडवांस्ड रिवीज़न सेट';
  @override
  String get benefitMockTests => 'अतिरिक्त मॉक टेस्ट और अभ्यास प्रश्न';
  @override
  String get comingSoonIncluded => 'जल्द आ रहा है · बिना अतिरिक्त शुल्क के शामिल';
  @override
  String get alwaysFree => 'हमेशा मुफ़्त';
  @override
  String get alwaysFreeBody => 'नोट्स, टॉपिक, वर्चुअल लैब, प्रैक्टिकल, अभ्यास प्रश्न, गलतियों का रिवीज़न, फ़ोकस मोड, आपके नोट्स और मूल प्रगति।';
  @override
  String buyFor(String price) => 'प्रीमियम खरीदें · $price';
  @override
  String get restore => 'खरीद रीस्टोर करें';
  @override
  String get active => 'प्रीमियम चालू है';
  @override
  String get activeBody => 'धन्यवाद! प्रीमियम की सभी सुविधाएँ खुल गई हैं।';
  @override
  String get pendingTitle => 'भुगतान लंबित है';
  @override
  String get pendingBody => 'Google Play द्वारा भुगतान की पुष्टि होते ही प्रीमियम अपने-आप खुल जाएगा।';
  @override
  String get linkedToPlay => 'प्रीमियम आपके Google Play खाते से जुड़ा है। नए फ़ोन पर या ऐप दोबारा इंस्टॉल करने के बाद "खरीद रीस्टोर करें" दबाएँ।';
  @override
  String get priceNote => 'भुगतान Google Play द्वारा होता है। Google Play में दिखाई गई कीमत ही अंतिम है।';
  @override
  String notice(PremiumNotice n) => switch (n) {
        PremiumNotice.purchased => 'खरीद की पुष्टि हो गई। प्रीमियम खुल गया!',
        PremiumNotice.restored => 'खरीद रीस्टोर हो गई। प्रीमियम खुल गया।',
        PremiumNotice.nothingToRestore => 'इस Google Play खाते पर कोई प्रीमियम खरीद नहीं मिली।',
        PremiumNotice.pending => 'आपका भुगतान लंबित है। पुष्टि होते ही प्रीमियम खुल जाएगा।',
        PremiumNotice.cancelled => 'खरीद रद्द हो गई। आपसे कोई शुल्क नहीं लिया गया।',
        PremiumNotice.failed => 'खरीद पूरी नहीं हो सकी। कृपया फिर से कोशिश करें। अगर आप प्रीमियम खरीद चुके हैं, तो "खरीद रीस्टोर करें" दबाएँ।',
        PremiumNotice.verifyFailed => 'भुगतान मिल गया, पर अभी पुष्टि नहीं हुई। इंटरनेट जाँचें और "खरीद रीस्टोर करें" दबाएँ।',
        PremiumNotice.rejected => 'Google Play से इस खरीद की पुष्टि नहीं हो सकी।',
        PremiumNotice.revoked => 'खरीद का रिफ़ंड या रद्द होने के कारण प्रीमियम हटा दिया गया।',
      };
  @override
  String unavailable(PremiumUnavailable u) => switch (u) {
        PremiumUnavailable.notConfigured => 'ऐप के इस संस्करण में खरीदारी सेट नहीं है।',
        PremiumUnavailable.storeUnavailable => 'Google Play उपलब्ध नहीं है। ऐप Google Play से इंस्टॉल करें और इंटरनेट जाँचें।',
        PremiumUnavailable.productUnavailable => 'प्रीमियम अभी खरीद के लिए उपलब्ध नहीं है। कृपया बाद में कोशिश करें।',
      };
  @override
  String get lockedTitle => 'प्रीमियम सुविधा';
  @override
  String get lockedPyqs => 'उत्तरों सहित पिछले वर्षों के प्रश्न प्रीमियम का हिस्सा हैं।';
  @override
  String get lockedAnalysis => 'सटीकता का विवरण और अध्याय-वार प्रगति प्रीमियम का हिस्सा हैं।';
  @override
  String unlockFor(String price) => '$price में अनलॉक करें';
  @override
  String get seePremium => 'प्रीमियम देखें';
}

extension PremiumStringsContext on BuildContext {
  /// Current Premium strings; rebuilds the caller when the language changes.
  PremiumStrings get premium => PremiumStrings.of(watch<LanguageController>().language);

  /// Current Premium strings without subscribing – for event handlers.
  PremiumStrings get readPremium => PremiumStrings.of(read<LanguageController>().language);
}
