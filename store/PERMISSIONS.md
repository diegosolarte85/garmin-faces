# Permissions justification

The Connect IQ Store shows the permissions a face requests. This face requests
exactly one, and only to populate optional complications the user turns on.

| Permission | Why it's needed | What happens without it |
| --- | --- | --- |
| **SensorHistory** | Read recent **heart rate** and **Body Battery** history for the optional left-subdial complications. The Connect IQ compiler requires this permission merely to *reference* the `Toybox.SensorHistory` API — even though the calls are also guarded at runtime. | The face still works fully; those two subdial options simply show `--`. |

What this face does **not** do:

- No network / internet access.
- No GPS or location.
- No background services or messaging.
- Battery, steps and active-minutes complications use `System.getSystemStats`
  and `ActivityMonitor`, which need no permission.

Data read via SensorHistory is used only to render the on-watch subdial and is
never transmitted anywhere.
