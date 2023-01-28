# Don't do anything until finding the relevant comment line.
/# --- Start Awk prerequisite checks here ---/ { active = "true" }
/.*/ { if (! active) next }

# Create a dependency for FROM statements .
/^FROM .* AS .*/ { pkg = $4; \
    if ($2 != "scratch" && !match($2, "ubuntu"))
        print "status/" pkg ".ok: status/" $2 ".ok" }
# And for each ADD statement.
/^ADD .* .*/ { print "status/" pkg ".ok: " $2 }
# And for copying from prior images.
/^COPY --from=.* .* .*/ { split($2, from, "=") ; \
    print "status/" pkg ".ok: status/" from[2] ".ok" }

# If we're adding sources, create a rule to download them.
/^ADD sources.* .*/ { src = $2 }
/^# https:/ { print src ":"; print "\t $(WGET_SRC) " $2 }
