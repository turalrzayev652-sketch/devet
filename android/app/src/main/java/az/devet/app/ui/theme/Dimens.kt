package az.devet.app.ui.theme

import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.ui.unit.dp

/** Spacing tokens (spec/design.md §4, 8-pt grid): `space.2` → [s2]. */
object Spacing {
    val s0_5 = 4.dp
    val s1 = 8.dp
    val s1_5 = 12.dp
    val s2 = 16.dp
    val s3 = 24.dp
    val s4 = 32.dp
    val s5 = 40.dp
    val s6 = 48.dp
    val s8 = 64.dp
    val gutter = 24.dp
}

/** Radius tokens: `radius.card` → [card]. */
object Radius {
    val sm = 8.dp
    val control = 14.dp
    val card = 20.dp
    val sheet = 28.dp
}

object Shapes {
    val control = RoundedCornerShape(Radius.control)
    val card = RoundedCornerShape(Radius.card)
    val sheet = RoundedCornerShape(topStart = Radius.sheet, topEnd = Radius.sheet)
    val pill = RoundedCornerShape(percent = 50)
}

/** Size tokens: touch target, control height, icon. */
object Sizes {
    val touchMin = 44.dp
    val controlHeight = 52.dp
    val chipHeight = 36.dp
    val icon = 24.dp
}

/** Motion tokens (ms). With "Remove animations" the system scales these to 0. */
object Motion {
    const val FAST = 200
    const val BASE = 250
    const val SLOW = 300
}
