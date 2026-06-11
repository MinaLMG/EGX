/**
 * Run with: node backend/scripts/seedFAQ.js
 */
require('dotenv').config({ path: require('path').join(__dirname, '../.env') });
const mongoose = require('mongoose');
const FAQ = require('../models/FAQ');

const faqs = [
    { 
        displayOrder: 1,  
        question: 'How do I add funds to my portfolio?',           
        questionAr: 'كيف أضيف أسهمًا إلى محفظتي؟',
        answer: 'Navigate to My Wallet, tap "+ Add Action", select a stock and enter the quantity and price you purchased at. This records your holding in the portfolio.',
        answerAr: 'انتقل إلى "محفظتي"، واضغط على "+ إضافة إجراء"، ثم اختر السهم وأدخل الكمية والسعر الذي اشتريت به. سيتم تسجيل ملكيتك في المحفظة.'
    },
    { 
        displayOrder: 2,  
        question: 'How do I remove a stock from my portfolio?',    
        questionAr: 'كيف أحذف سهمًا من محفظتي؟',
        answer: 'Open My Wallet, find the stock entry, swipe left or tap the delete icon to remove it from your portfolio tracking.',
        answerAr: 'افتح "محفظتي"، وابحث عن السهم المطلوب، ثم اضغط على أيقونة الحذف لإزالته من تتبع محفظتك.'
    },
    { 
        displayOrder: 3,  
        question: 'How do I edit portfolio actions?',               
        questionAr: 'كيف يمكنني تعديل الإجراءات في المحفظة؟',
        answer: 'Tap on an existing portfolio entry to open the edit form. You can update the quantity, price, or action type, then save your changes.',
        answerAr: 'اضغط على أي إجراء موجود لفتح نموذج التعديل. يمكنك تحديث الكمية أو السعر ثم حفظ التغييرات.'
    },
    { 
        displayOrder: 4,  
        question: 'What is the difference between Pending and Next?', 
        questionAr: 'ما الفرق بين الإجراءات "المعلقة" و"التالية"؟',
        answer: 'Pending actions are trades triggered at your last rebalancing price, waiting to be executed. Next actions show the upcoming rebalancing trigger — the price and quantity for your next scheduled trade.',
        answerAr: 'الإجراءات المعلقة هي صفقات تم تفعيلها عند آخر سعر لإعادة التوازن وتنتظر التنفيذ. أما الإجراءات التالية فتُظهر سعر التفعيل والكمية لصفقتك المجدولة القادمة.'
    },
    { 
        displayOrder: 5,  
        question: 'How is Revenue calculated?',                    
        questionAr: 'كيف يتم حساب الربح؟',
        answer: 'Revenue is calculated as (Current Market Value − Total Cost Basis). It represents unrealised gain or loss across your entire portfolio position.',
        answerAr: 'يتم حساب الربح كـ (القيمة السوقية الحالية - إجمالي التكلفة). ويمثل الأرباح أو الخسائر غير المحققة عبر محفظتك بالكامل.'
    },
    { 
        displayOrder: 6,  
        question: 'How are buy recommendations generated?',        
        questionAr: 'كيف يتم إنشاء توصيات الشراء؟',
        answer: 'Buy recommendations are generated when a stock\'s current market price falls below its calculated fair value by a significant margin, suggesting it is undervalued.',
        answerAr: 'يتم إنشاء توصيات الشراء عندما يقل سعر السوق الحالي للسهم عن قيمته العادلة المحسوبة بهامش كبير، مما يشير إلى أن قيمته أقل من الحقيقية.'
    },
    { 
        displayOrder: 7,  
        question: 'How are sell recommendations generated?',       
        questionAr: 'كيف يتم إنشاء توصيات البيع؟',
        answer: 'Sell recommendations appear when a stock\'s market price rises above its fair value threshold, indicating it may be overvalued compared to its fundamentals.',
        answerAr: 'تظهر توصيات البيع عندما يرتفع سعر السوق للسهم فوق القيمة العادلة، مما يشير إلى أن السعر قد يكون مبالغًا فيه مقارنة بالأساسيات.'
    },
    { 
        displayOrder: 8,  
        question: 'How often is portfolio data updated?',           
        questionAr: 'كم مرة يتم تحديث بيانات المحفظة؟',
        answer: 'Portfolio valuations are recalculated every time stock prices are updated during market hours, typically every few minutes when the EGX is open.',
        answerAr: 'يتم إعادة حساب قيم المحفظة في كل مرة يتم فيها تحديث أسعار الأسهم خلال ساعات عمل السوق (البورصة المصرية).'
    },
    { 
        displayOrder: 9,  
        question: 'How are stock scores calculated?',               
        questionAr: 'كيف يتم حساب نتائج (Scores) الأسهم؟',
        answer: 'Scores are derived from a combination of fundamental analysis metrics (P/E ratio, earnings growth) and technical indicators. Each strategy weighs these factors differently.',
        answerAr: 'النتائج مشتقة من مزيج من مقاييس التحليل الأساسي (مثل مكرر الربحية) والمؤشرات الفنية. كل استراتيجية تزن هذه العوامل بشكل مختلف.'
    },
    { 
        displayOrder: 10, 
        question: 'How do notifications work?',                    
        questionAr: 'كيف تعمل الإشعارات؟',
        answer: 'Push notifications are sent when your portfolio has a new pending action or when a rebalancing threshold is triggered. All notifications are mandatory for active accounts.',
        answerAr: 'يتم إرسال إشعارات فورية عند وجود إجراء معلق جديد أو عند الوصول لسعر إعادة التوازن. جميع الإشعارات إلزامية للحسابات النشطة.'
    },
    { 
        displayOrder: 11, 
        question: 'What should I do if I entered the wrong quantity?', 
        questionAr: 'ماذا أفعل إذا أدخلت كمية خاطئة؟',
        answer: 'Tap on the affected portfolio entry, select Edit, correct the quantity, and save. Your portfolio totals will recalculate automatically.',
        answerAr: 'اضغط على السهم في المحفظة، اختر تعديل، صحح الكمية واضغط حفظ. سيتم إعادة حساب الإجماليات تلقائيًا.'
    },
    { 
        displayOrder: 12, 
        question: 'Can I recover a deleted portfolio action?',     
        questionAr: 'هل يمكن استعادة إجراء محذوف؟',
        answer: 'No. Once a portfolio action is deleted it is permanently removed. We recommend double-checking before confirming any deletion.',
        answerAr: 'لا، بمجرد حذف الإجراء يتم إزالته نهائيًا. نوصي بالتأكد جيدًا قبل الحذف.'
    },
];

async function seed() {
    try {
        await mongoose.connect(process.env.MONGO_URI);
        console.log('Connected to MongoDB');

        await FAQ.deleteMany({});
        console.log('Cleared existing FAQs');

        const created = await FAQ.insertMany(faqs);
        console.log(`Seeded ${created.length} FAQs with Arabic support`);

        await mongoose.disconnect();
        console.log('Done.');
    } catch (error) {
        console.error('Error seeding FAQs:', error);
        process.exit(1);
    }
}

seed();
