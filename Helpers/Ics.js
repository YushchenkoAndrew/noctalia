// Minimal iCalendar (RFC 5545) reader used by the native calendar provider.
// No external dependencies: works on plain .ics text and expands the common recurrence rules.
//
// Time handling: UTC ("...Z") times are converted exactly. Floating times and TZID times are
// interpreted in the system's local timezone (VTIMEZONE definitions are not evaluated).
.pragma library

var MAX_ITERATIONS = 20000;
var DAY_CODES = ["SU", "MO", "TU", "WE", "TH", "FR", "SA"];

// ---------------------------------------------------------------------------
// Parsing
// ---------------------------------------------------------------------------

function unfold(text) {
  var raw = text.replace(/\r\n/g, "\n").replace(/\r/g, "\n").split("\n");
  var lines = [];
  for (var i = 0; i < raw.length; i++) {
    var l = raw[i];
    if ((l.charAt(0) === " " || l.charAt(0) === "\t") && lines.length > 0)
      lines[lines.length - 1] += l.substring(1);
    else
      lines.push(l);
  }
  return lines;
}

function parseLine(line) {
  // NAME;PARAM=VALUE;PARAM="quoted:value":VALUE
  var inQuote = false, colon = -1;
  for (var i = 0; i < line.length; i++) {
    var c = line.charAt(i);
    if (c === '"')
      inQuote = !inQuote;
    else if (c === ":" && !inQuote) {
      colon = i;
      break;
    }
  }
  if (colon < 0)
    return null;
  var head = line.substring(0, colon);
  var value = line.substring(colon + 1);
  var parts = [], cur = "";
  inQuote = false;
  for (var j = 0; j < head.length; j++) {
    var ch = head.charAt(j);
    if (ch === '"')
      inQuote = !inQuote;
    if (ch === ";" && !inQuote) {
      parts.push(cur);
      cur = "";
    } else
      cur += ch;
  }
  parts.push(cur);
  var params = {};
  for (var k = 1; k < parts.length; k++) {
    var eq = parts[k].indexOf("=");
    if (eq > 0)
      params[parts[k].substring(0, eq).toUpperCase()] = parts[k].substring(eq + 1).replace(/"/g, "");
  }
  return {
    "name": parts[0].toUpperCase(),
    "params": params,
    "value": value
  };
}

function unescapeText(v) {
  return v.replace(/\\n/gi, "\n").replace(/\\,/g, ",").replace(/\\;/g, ";").replace(/\\\\/g, "\\");
}

// Returns {ms, allDay, utc}
function parseDateValue(value, params) {
  var v = value.trim();
  var m = /^(\d{4})(\d{2})(\d{2})(?:T(\d{2})(\d{2})(\d{2})?(Z)?)?$/.exec(v);
  if (!m)
    return null;
  var y = parseInt(m[1], 10), mo = parseInt(m[2], 10) - 1, d = parseInt(m[3], 10);
  if (m[4] === undefined || (params && params["VALUE"] === "DATE")) {
    return {
      "ms": new Date(y, mo, d, 0, 0, 0).getTime(),
      "allDay": true,
      "utc": false
    };
  }
  var H = parseInt(m[4], 10), M = parseInt(m[5], 10), S = m[6] ? parseInt(m[6], 10) : 0;
  if (m[7] === "Z") {
    return {
      "ms": Date.UTC(y, mo, d, H, M, S),
      "allDay": false,
      "utc": true
    };
  }
  return {
    "ms": new Date(y, mo, d, H, M, S).getTime(),
    "allDay": false,
    "utc": false
  };
}

// "P1DT2H30M", "PT45M", "P2W" -> milliseconds
function parseDuration(v) {
  var m = /^([+-])?P(?:(\d+)W)?(?:(\d+)D)?(?:T(?:(\d+)H)?(?:(\d+)M)?(?:(\d+)S)?)?$/.exec(v.trim());
  if (!m)
    return 0;
  var ms = ((parseInt(m[2] || 0, 10) * 7 + parseInt(m[3] || 0, 10)) * 86400 + parseInt(m[4] || 0, 10) * 3600 + parseInt(m[5] || 0, 10) * 60 + parseInt(m[6] || 0, 10)) * 1000;
  return m[1] === "-" ? -ms : ms;
}

function parseRRule(v) {
  var r = {
    "freq": "",
    "interval": 1,
    "count": 0,
    "until": null,
    "byday": [],
    "bymonthday": [],
    "bymonth": []
  };
  var parts = v.split(";");
  for (var i = 0; i < parts.length; i++) {
    var eq = parts[i].indexOf("=");
    if (eq < 0)
      continue;
    var k = parts[i].substring(0, eq).toUpperCase(), val = parts[i].substring(eq + 1);
    if (k === "FREQ")
      r.freq = val.toUpperCase();
    else if (k === "INTERVAL")
      r.interval = Math.max(1, parseInt(val, 10) || 1);
    else if (k === "COUNT")
      r.count = parseInt(val, 10) || 0;
    else if (k === "UNTIL") {
      var u = parseDateValue(val, {});
      if (u)
        r.until = u.allDay ? u.ms + 86400000 - 1 : u.ms;
    } else if (k === "BYDAY") {
      var ds = val.split(",");
      for (var j = 0; j < ds.length; j++) {
        var dm = /^([+-]?\d+)?(SU|MO|TU|WE|TH|FR|SA)$/.exec(ds[j].trim().toUpperCase());
        if (dm)
          r.byday.push({
                         "n": dm[1] ? parseInt(dm[1], 10) : 0,
                         "day": DAY_CODES.indexOf(dm[2])
                       });
      }
    } else if (k === "BYMONTHDAY")
      r.bymonthday = val.split(",").map(function (x) {
        return parseInt(x, 10);
      });
    else if (k === "BYMONTH")
      r.bymonth = val.split(",").map(function (x) {
        return parseInt(x, 10);
      });
  }
  return r;
}

// Parse ics text into raw VEVENT objects
function parseEvents(text) {
  var lines = unfold(text);
  var events = [];
  var cur = null;
  for (var i = 0; i < lines.length; i++) {
    var line = lines[i];
    if (line === "BEGIN:VEVENT") {
      cur = {
        "uid": "",
        "summary": "",
        "location": "",
        "description": "",
        "start": null,
        "end": null,
        "duration": null,
        "rrule": null,
        "exdates": [],
        "recurrenceId": null,
        "cancelled": false
      };
      continue;
    }
    if (line === "END:VEVENT") {
      if (cur && cur.start)
        events.push(cur);
      cur = null;
      continue;
    }
    if (!cur)
      continue;
    var p = parseLine(line);
    if (!p)
      continue;
    switch (p.name) {
    case "UID":
      cur.uid = p.value;
      break;
    case "SUMMARY":
      cur.summary = unescapeText(p.value);
      break;
    case "LOCATION":
      cur.location = unescapeText(p.value);
      break;
    case "DESCRIPTION":
      cur.description = unescapeText(p.value);
      break;
    case "STATUS":
      cur.cancelled = p.value.toUpperCase() === "CANCELLED";
      break;
    case "DTSTART":
      cur.start = parseDateValue(p.value, p.params);
      break;
    case "DTEND":
      cur.end = parseDateValue(p.value, p.params);
      break;
    case "DURATION":
      cur.duration = parseDuration(p.value);
      break;
    case "RRULE":
      cur.rrule = parseRRule(p.value);
      break;
    case "EXDATE":
      var xs = p.value.split(",");
      for (var x = 0; x < xs.length; x++) {
        var xd = parseDateValue(xs[x], p.params);
        if (xd)
          cur.exdates.push(xd);
      }
      break;
    case "RECURRENCE-ID":
      cur.recurrenceId = parseDateValue(p.value, p.params);
      break;
    }
  }
  return events;
}

// ---------------------------------------------------------------------------
// Date helpers (local or UTC civil time)
// ---------------------------------------------------------------------------

function mk(y, mo, d, H, M, S, utc) {
  return utc ? Date.UTC(y, mo, d, H, M, S) : new Date(y, mo, d, H, M, S).getTime();
}

function parts(ms, utc) {
  var d = new Date(ms);
  return utc ? {
                 "y": d.getUTCFullYear(),
                 "mo": d.getUTCMonth(),
                 "d": d.getUTCDate(),
                 "H": d.getUTCHours(),
                 "M": d.getUTCMinutes(),
                 "S": d.getUTCSeconds(),
                 "dow": d.getUTCDay()
               } : {
                 "y": d.getFullYear(),
                 "mo": d.getMonth(),
                 "d": d.getDate(),
                 "H": d.getHours(),
                 "M": d.getMinutes(),
                 "S": d.getSeconds(),
                 "dow": d.getDay()
               };
}

function daysInMonth(y, mo) {
  return new Date(Date.UTC(y, mo + 1, 0)).getUTCDate();
}

// date (1..31) of the n-th `dow` of a month; n<0 counts from the end. Returns 0 if absent.
function nthWeekday(y, mo, dow, n) {
  var first = new Date(Date.UTC(y, mo, 1)).getUTCDay();
  var dim = daysInMonth(y, mo);
  if (n > 0) {
    var d = 1 + ((dow - first + 7) % 7) + (n - 1) * 7;
    return d <= dim ? d : 0;
  }
  var last = new Date(Date.UTC(y, mo, dim)).getUTCDay();
  var dl = dim - ((last - dow + 7) % 7) + (n + 1) * 7;
  return dl >= 1 ? dl : 0;
}

function allWeekdays(y, mo, dow) {
  var out = [], first = nthWeekday(y, mo, dow, 1), dim = daysInMonth(y, mo);
  for (var d = first; d && d <= dim; d += 7)
    out.push(d);
  return out;
}

// ---------------------------------------------------------------------------
// Expansion
// ---------------------------------------------------------------------------

function eventDurationMs(ev) {
  if (ev.end)
    return Math.max(0, ev.end.ms - ev.start.ms);
  if (ev.duration !== null)
    return ev.duration;
  return ev.start.allDay ? 86400000 : 0;
}

// Candidate start times (ms) of a recurring event, ascending, up to `limitMs`
function occurrences(ev, limitMs) {
  var rule = ev.rrule;
  var utc = ev.start.utc;
  var s = parts(ev.start.ms, utc);
  var out = [];
  var count = 0;

  function push(y, mo, d) {
    var t = mk(y, mo, d, s.H, s.M, s.S, utc);
    if (t < ev.start.ms)
      return true;
    if (rule.until !== null && t > rule.until)
      return false;
    if (t > limitMs)
      return false;
    out.push(t);
    count++;
    return !(rule.count > 0 && count >= rule.count);
  }

  var iter = 0;
  if (rule.freq === "DAILY") {
    for (var i = 0; iter++ < MAX_ITERATIONS; i += rule.interval) {
      var t0 = mk(s.y, s.mo, s.d + i, s.H, s.M, s.S, utc);
      var pp = parts(t0, utc);
      if (rule.bymonth.length && rule.bymonth.indexOf(pp.mo + 1) < 0)
        continue;
      if (rule.byday.length && !rule.byday.some(function (b) {
        return b.day === pp.dow;
      }))
        continue;
      if (!push(pp.y, pp.mo, pp.d))
        break;
    }
  } else if (rule.freq === "WEEKLY") {
    var days = rule.byday.length ? rule.byday.map(function (b) {
      return b.day;
    }) : [s.dow];
    days.sort(function (a, b) {
      return ((a + 6) % 7) - ((b + 6) % 7);
    });                                          // Monday-first week
    var weekStart = s.d - ((s.dow + 6) % 7);     // Monday of the first week
    outer: for (var w = 0; iter++ < MAX_ITERATIONS; w += rule.interval) {
      for (var di = 0; di < days.length; di++) {
        var off = (days[di] + 6) % 7;
        var tw = mk(s.y, s.mo, weekStart + w * 7 + off, s.H, s.M, s.S, utc);
        var pw = parts(tw, utc);
        if (rule.bymonth.length && rule.bymonth.indexOf(pw.mo + 1) < 0)
          continue;
        if (tw < ev.start.ms)
          continue;
        if (!push(pw.y, pw.mo, pw.d))
          break outer;
      }
      if (mk(s.y, s.mo, weekStart + w * 7, 0, 0, 0, utc) > limitMs)
        break;
    }
  } else if (rule.freq === "MONTHLY") {
    for (var m = 0; iter++ < MAX_ITERATIONS; m += rule.interval) {
      var base = new Date(Date.UTC(s.y, s.mo + m, 1));
      var y = base.getUTCFullYear(), mo = base.getUTCMonth();
      if (mk(y, mo, 1, 0, 0, 0, utc) > limitMs)
        break;
      if (rule.bymonth.length && rule.bymonth.indexOf(mo + 1) < 0)
        continue;
      var dates = [];
      if (rule.byday.length) {
        rule.byday.forEach(function (b) {
          if (b.n === 0)
            dates = dates.concat(allWeekdays(y, mo, b.day));
          else {
            var nd = nthWeekday(y, mo, b.day, b.n);
            if (nd)
              dates.push(nd);
          }
        });
      } else if (rule.bymonthday.length) {
        rule.bymonthday.forEach(function (bd) {
          var dd = bd > 0 ? bd : daysInMonth(y, mo) + bd + 1;
          if (dd >= 1 && dd <= daysInMonth(y, mo))
            dates.push(dd);
        });
      } else if (s.d <= daysInMonth(y, mo))
        dates.push(s.d);
      dates.sort(function (a, b) {
        return a - b;
      });
      var stop = false;
      for (var k = 0; k < dates.length; k++) {
        if (!push(y, mo, dates[k])) {
          stop = true;
          break;
        }
      }
      if (stop)
        break;
    }
  } else if (rule.freq === "YEARLY") {
    for (var yy = 0; iter++ < MAX_ITERATIONS; yy += rule.interval) {
      var yr = s.y + yy;
      if (mk(yr, 0, 1, 0, 0, 0, utc) > limitMs)
        break;
      var months = rule.bymonth.length ? rule.bymonth.map(function (x) {
        return x - 1;
      }) : [s.mo];
      var stopY = false;
      for (var mi = 0; mi < months.length && !stopY; mi++) {
        var mon = months[mi], ds = [];
        if (rule.byday.length) {
          rule.byday.forEach(function (b) {
            if (b.n === 0)
              ds = ds.concat(allWeekdays(yr, mon, b.day));
            else {
              var nd2 = nthWeekday(yr, mon, b.day, b.n);
              if (nd2)
                ds.push(nd2);
            }
          });
        } else if (rule.bymonthday.length) {
          rule.bymonthday.forEach(function (bd) {
            ds.push(bd > 0 ? bd : daysInMonth(yr, mon) + bd + 1);
          });
        } else if (s.d <= daysInMonth(yr, mon))
          ds.push(s.d);
        ds.sort(function (a, b) {
          return a - b;
        });
        for (var q = 0; q < ds.length; q++) {
          if (!push(yr, mon, ds[q])) {
            stopY = true;
            break;
          }
        }
      }
      if (stopY)
        break;
    }
  }
  return out;
}

function sameInstant(a, b) {
  return a.allDay || b.allDay ? Math.floor(a.ms / 86400000) === Math.floor(b.ms / 86400000) : a.ms === b.ms;
}

// Turn raw VEVENTs into display events overlapping [rangeStartMs, rangeEndMs)
// Output: {calendar, summary, start, end (epoch seconds), location, description, uid}
function expand(rawEvents, rangeStartMs, rangeEndMs, calendarName) {
  var out = [];

  // Overrides of single occurrences (RECURRENCE-ID), keyed by uid
  var overrides = {};
  rawEvents.forEach(function (ev) {
    if (ev.recurrenceId) {
      (overrides[ev.uid] = overrides[ev.uid] || []).push(ev);
    }
  });

  function emit(ev, startMs, endMs) {
    if (ev.cancelled)
      return;
    if (!(endMs > rangeStartMs && startMs < rangeEndMs) && !(startMs >= rangeStartMs && startMs < rangeEndMs))
      return;
    out.push({
               "calendar": calendarName,
               "summary": ev.summary,
               "start": Math.floor(startMs / 1000),
               "end": Math.floor(endMs / 1000),
               "location": ev.location,
               "description": ev.description,
               "uid": ev.uid
             });
  }

  rawEvents.forEach(function (ev) {
    var dur = eventDurationMs(ev);
    if (ev.recurrenceId) {
      emit(ev, ev.start.ms, ev.start.ms + dur);
      return;
    }
    if (!ev.rrule || !ev.rrule.freq) {
      emit(ev, ev.start.ms, ev.start.ms + dur);
      return;
    }
    var times = occurrences(ev, rangeEndMs);
    var ovs = overrides[ev.uid] || [];
    for (var i = 0; i < times.length; i++) {
      var t = times[i];
      if (t + dur <= rangeStartMs)
        continue;
      var skip = false;
      for (var x = 0; x < ev.exdates.length && !skip; x++)
        skip = sameInstant({
                             "ms": t,
                             "allDay": ev.start.allDay
                           }, ev.exdates[x]);
      for (var o = 0; o < ovs.length && !skip; o++)
        skip = sameInstant({
                             "ms": t,
                             "allDay": ev.start.allDay
                           }, ovs[o].recurrenceId);
      if (skip)
        continue;
      emit(ev, t, t + dur);
    }
  });

  out.sort(function (a, b) {
    return a.start - b.start || a.end - b.end;
  });
  return out;
}

// Convenience: text -> events in range
function eventsFromText(text, rangeStartMs, rangeEndMs, calendarName) {
  return expand(parseEvents(text), rangeStartMs, rangeEndMs, calendarName);
}
