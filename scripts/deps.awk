/# --- Start Awk prerequisite checks here ---/ { active = "true" }
/.*/ { if (! active) next }
/^FROM .* AS .*/ { pkg = $4 }
/^ADD sources.* .*/ { src = $2 }
/^ADD .* .*/ { print "status/" pkg ".ok: " $2 }
/^# https:/ { print src ":"; print "\t $(WGET_SRC) " $2 }
