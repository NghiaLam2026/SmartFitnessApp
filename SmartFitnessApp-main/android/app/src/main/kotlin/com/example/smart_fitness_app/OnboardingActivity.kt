import android.app.Activity
import android.os.bundle
import android.widget.ScrollView
import android.widget.TextView
import android.view.Gravity

/** 

* health connect OnboardingActivity
* this screen is displayed when users view onboarding info from health connect.
*/

class OnboardingActivity : Activity(){
    override fun onCreate(savedInstanceState: Bundle?){
        super.onCreate(savedInstanceState)
        val scrollView = ScrollView(this)
        val textView = TextView(this)

        textView.text = """
            Welcome to Smart Fitness App!

            This app connects with health connect to access your step count and heart rate data. we use this information only to show your daily activity progress inside the app.
        """.trimIndent()

        textView.textSize = 18f
        textView.gravity = Gravity.START 
        textView.setPadding(48,48,48,48)

        scrollView.addView(textView)
        setContentView(scrollView)
    }
}