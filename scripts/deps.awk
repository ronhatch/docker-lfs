# Don't do anything until finding the relevant comment line.
/# --- Start Awk prerequisite checks here ---/ { active = "true" }
/.*/ { if (! active) next }

# Create a dependency for each ADD statement.
/^FROM .* AS .*/ { pkg = $4 }
/^ADD .* .*/ { print "status/" pkg ".ok: " $2 }

# If we're adding sources, create a rule to download them.
/^ADD sources.* .*/ { src = $2 }
/^# https:/ { print src ":"; print "\t $(WGET_SRC) " $2 }
