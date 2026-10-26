package com.atahad.atahad

import android.app.Activity
import android.os.Bundle
import android.widget.ScrollView
import android.widget.TextView
import android.view.View

/** Dedicated destination for Health Connect's permission rationale and usage link. */
class HealthPermissionsActivity : Activity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        val text = TextView(this).apply {
            textSize = 18f
            setPadding(36, 64, 36, 64)
            layoutDirection = View.LAYOUT_DIRECTION_RTL
            text = "خصوصية خطواتك في أتعهّد\n\n" +
                "نطلب قراءة عدد الخطوات فقط، ولا نكتب أو نغيّر بيانات تطبيق الصحة.\n\n" +
                "نرسل مجموع خطوات اليوم وتاريخه ومصدر القراءة إلى حسابك في أتعهّد لمتابعة هدف المشي واحتساب الإنجاز. لا نرسل عينات الحركة أو سجل المواقع ضمن ميزة المشي.\n\n" +
                "تقدر تسحب الإذن من Health Connect في أي وقت وتستخدم صورة خطوات اليوم للمراجعة. تُحذف بيانات الربط والخطوات عند حذف حسابك.\n\n" +
                "المجموع محسوب بتوقيت الرياض. الرجوع يعيدك إلى شاشة الصلاحيات."
        }
        setContentView(ScrollView(this).apply { addView(text) })
    }
}
