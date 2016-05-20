/+
    DBuildTime
    Based on CTime by Casey Muratori

    Copyright © 2016, Daniel Kurashige-Gollub <daniel@kurashige-gollub.de>
+/

// TODO(dkg): clean up the imports and only import what's needed!
import std.datetime;
import std.string;
import std.stdio;
import std.conv;
import std.file;
import std.format;


immutable int MAGIC_VALUE = 0xCA5E713F;

// NOTE(dkg): make sure we keep the original structs' memory aligments!
// #pragma pack(push,1)
align(1)
struct timing_file_header
{
    uint MagicValue;
}

align(1)
struct timing_file_date
{
    ulong E;
}

// TODO(dkg): convert these to an enum
immutable int TFEF_Complete = 0x1;
immutable int TFEF_NoErrors = 0x2;

align(1)
struct timing_file_entry
{
    timing_file_date StartDate;
    uint Flags;
    uint MillisecondsElapsed;
}

ulong GetClockInNSecs()
{
    auto now = MonoTime.currTime;
    return ticksToNSecs(now.ticks());
}

timing_file_date GetDate()
{
    auto now = Clock.currTime.toUTC();

    timing_file_date result = { E: now.toUnixTime() };

    return result;
}

void PrintDate(timing_file_date date) {
    auto time = SysTime.fromUnixTime(date.E).toLocalTime();
    auto tinu = time.toTM();

    // unfortunately have to do it "manually" here
    import core.stdc.time : strftime;
    char[256] buffer;

    strftime(cast(char *)&buffer, 256UL, toStringz("%Y-%m-%d %H:%M:%S"), &tinu);

    write(fromStringz(cast(char *)&buffer));
}

ulong SecondDifference(timing_file_date a, timing_file_date b)
{
    ulong diff = a.E - b.E;
    return diff;
}

uint DayIndex(timing_file_date a)
{
    auto ts = SysTime.fromUnixTime(a.E).toTM();
    return ts.tm_yday;
}

void Usage()
{
    stderr.write("DBuildTime v1.0 by Daniel Kurashige-Gollub\n");
    stderr.write("Based on CTime v1.0 by Casey Muratori\n");
    stderr.write("Usage:\n");
    stderr.write("  dbuildtime --begin <timing file>\n");
    stderr.write("  dbuildtime --end <timing file> [error level]\n");
    stderr.write("  dbuildtime --stats <timing file>\n");
    stderr.write("  dbuildtime --csv <timing file>\n");
}

// TODO(dkg): refactor this
timing_file_entry[] ReadAllEntries(File timingFile)
{
    ulong fileSize = timingFile.size();
    ulong entriesBegin = timing_file_header.sizeof;
    ulong entrySize = timing_file_entry.sizeof;
    ulong entriesSize = fileSize - entriesBegin;

    ulong numberOfEntries = entriesSize / entrySize;

    if (fileSize > 0)
    {
        timing_file_entry[] buffer;
        buffer.length = numberOfEntries;

        timingFile.seek(entriesBegin, SEEK_SET);
        auto result = timingFile.rawRead(buffer);

        if (result.length != numberOfEntries)
        {
            stderr.writef("ERROR: Unable to read timing entries from file.\n");
            return [];
        }

        return result;
    }
    else
    {
        stderr.writef("ERROR: Unable to determine file size of timing file.\n");
    }

    return [];
}

void CSV(timing_file_entry[] entries, string timingFileName)
{
    writef("%s Timings\n", timingFileName);
    write("ordinal, date, duration, status\n");
    {
        foreach (entryIndex, entry; entries)
        {
            writef("%d, ", entryIndex);
            PrintDate(entry.StartDate);
            if (entry.Flags & TFEF_Complete)
            {
                writef(", %0.3fs, %s",
                    cast(double)entry.MillisecondsElapsed / 1000.0,
                    (entry.Flags & TFEF_NoErrors) ? "succeeded" : "failed");
            }
            else
            {
                write(", (never completed), failed");
            }

            write("\n");
        }
    }
}

struct time_part
{
    string Name;
    double MilliSecondsPer;
}

void PrintTime(double milliSeconds)
{
    double milliSecondsPerSecond = 1000;
    double milliSecondsPerMinute = 60 * milliSecondsPerSecond;
    double milliSecondsPerHour = 60 * milliSecondsPerMinute;
    double milliSecondsPerDay = 24 * milliSecondsPerHour;
    double milliSecondsPerWeek = 7 * milliSecondsPerDay;

    time_part[] parts = [
        {
            "week", milliSecondsPerWeek
        },
        {
            "day", milliSecondsPerDay
        },
        {
            "hour", milliSecondsPerHour
        },
        {
            "minute", milliSecondsPerMinute
        },
    ];

    double q = milliSeconds;

    foreach (part; parts)
    {
        uint msPer = cast(uint)part.MilliSecondsPer;
        uint value = cast(uint)(q / msPer);

        if (value > 0)
        {
            writef("%d %s%s, ", value, part.Name, (value != 1) ? "s" : "");
        }
        q -= value * msPer;
    }

    // TODO(dkg): nicer output for minute/hour/day long times
    writef("%0.3f seconds", cast(double) q / 1000.0);
}

void PrintTimeStat(string name, double milliSeconds)
{
    writef("%s: ", name);
    PrintTime(milliSeconds);
    write("\n");
}

struct stat_group
{
    uint Count = 0;

    uint SlowestMs = 0;
    uint FastestMs = 0;
    double TotalMs = 0;
}

immutable int GRAPH_HEIGHT = 10;
immutable int GRAPH_WIDTH = 30;

struct stat_graph
{
    stat_group[GRAPH_WIDTH] Buckets;
}

void PrintStatGroup(string title, stat_group group)
{
    uint averageMs = 0;
    if (group.Count >= 1)
    {
        averageMs = cast(uint)(group.TotalMs / cast(double) group.Count);
    }

    if (group.Count > 0)
    {
        writef("%s (%d):\n", title, group.Count);
        PrintTimeStat("  Slowest", group.SlowestMs);
        PrintTimeStat("  Fastest", group.FastestMs);
        PrintTimeStat("  Average", averageMs);
        PrintTimeStat("  Total", group.TotalMs);
    }
}

void UpdateStatGroup(stat_group* group, timing_file_entry* entry)
{
    if (group.SlowestMs < entry.MillisecondsElapsed)
    {
        group.SlowestMs = entry.MillisecondsElapsed;
    }

    if (group.FastestMs > entry.MillisecondsElapsed)
    {
        group.FastestMs = entry.MillisecondsElapsed;
    }

    group.TotalMs += cast(double)entry.MillisecondsElapsed;

    ++group.Count;
}

int MapToDiscrete(double value, double inMax, double outMax)
{
    if (inMax == 0)
    {
        inMax = 1;
    }

    return cast(int)((value / inMax) * outMax);
}

void PrintGraph(string title, double daySpan, stat_graph graph)
{
    int bucketIndex;
    int lineIndex;
    int maxCountInBucket = 0;
    uint slowestMs = 0;
    double DPB = daySpan / cast(double) GRAPH_WIDTH;

    for (bucketIndex = 0; bucketIndex < GRAPH_WIDTH; ++bucketIndex)
    {
        stat_group group = graph.Buckets[bucketIndex];

        if (group.Count)
        {
            if (maxCountInBucket < group.Count)
            {
                maxCountInBucket = group.Count;
            }

            if (slowestMs < group.SlowestMs)
            {
                slowestMs = group.SlowestMs;
            }
        }
    }

    writef("\n%s (%f day%s/bucket):\n", title, DPB, (DPB == 1) ? "" : "s");

    for (lineIndex = GRAPH_HEIGHT - 1; lineIndex >= 0; --lineIndex)
    {
        write('|');
        for (bucketIndex = 0; bucketIndex < GRAPH_WIDTH; ++bucketIndex)
        {
            stat_group group = graph.Buckets[bucketIndex];
            int v = -1;
            if (group.Count)
            {
                v = MapToDiscrete(group.SlowestMs, slowestMs, GRAPH_HEIGHT - 1);
            }
            write((v >= lineIndex) ? '*' : ' ');
        }
        if (lineIndex == (GRAPH_HEIGHT - 1))
        {
            write(' ');
            PrintTime(slowestMs);
        }
        write('\n');
    }

    write('+');

    for (bucketIndex = 0; bucketIndex < GRAPH_WIDTH; ++bucketIndex)
    {
        write('-');
    }

    write(' ');

    PrintTime(0);

    write('\n');
    write('\n');

    for (lineIndex = GRAPH_HEIGHT - 1; lineIndex >= 0; --lineIndex)
    {
        write('|');
        for (bucketIndex = 0; bucketIndex < GRAPH_WIDTH; ++bucketIndex)
        {
            stat_group group = graph.Buckets[bucketIndex];
            int v = -1;
            if (group.Count)
            {
                v = MapToDiscrete(group.Count, maxCountInBucket, GRAPH_HEIGHT - 1);
            }
            write((v >= lineIndex) ? '*' : ' ');
        }
        if (lineIndex == (GRAPH_HEIGHT - 1))
        {
            writef(" %d", maxCountInBucket);
        }
        write('\n');
    }

    write('+');

    for (bucketIndex = 0; bucketIndex < GRAPH_WIDTH; ++bucketIndex)
    {
        write('-');
    }

    write(" 0\n");
}

void Stats(timing_file_entry[] entries, string timingFileName)
{
    stat_group withErrors;
    stat_group noErrors;
    stat_group allStats;

    uint incompleteCount = 0;
    uint daysWithTimingCount = 0;
    uint daySpanCount = 0;

    uint lastDayIndex = 0;

    double allMs = 0;

    uint firstRecentEntry = 0;

    double firstDayAt = 0;
    double lastDayAt = 0;
    double daySpan = 0;

    stat_graph totalGraph;
    stat_graph recentGraph;

    withErrors.FastestMs = 0xFFFFFFFF;
    noErrors.FastestMs = 0xFFFFFFFF;

    if (entries.length >= 2)
    {
        double secondsDiff = SecondDifference(entries[$-1].StartDate, entries[0].StartDate);
        daySpanCount = cast(uint)(secondsDiff / (60 * 60 * 24));

        firstDayAt = cast(double) DayIndex(entries[0].StartDate);
        lastDayAt = cast(double) DayIndex(entries[$-1].StartDate);
        daySpan = (lastDayAt - firstDayAt);
    }
    daySpan += 1;

    foreach (entry; entries)
    {
        if (entry.Flags & TFEF_Complete)
        {
            stat_group* group = (entry.Flags & TFEF_NoErrors) ? &noErrors : &withErrors;

            uint thisDayIndex = DayIndex(entry.StartDate);
            if (lastDayIndex != thisDayIndex)
            {
                lastDayIndex = thisDayIndex;
                ++daysWithTimingCount;
            }

            UpdateStatGroup(group, &entry);
            UpdateStatGroup(&allStats, &entry);

            allMs += cast(double)entry.MillisecondsElapsed;

            {
                int graphIndex = cast(int)((cast(double)(thisDayIndex - firstDayAt) / daySpan) * cast(double) GRAPH_WIDTH);
                UpdateStatGroup(&(totalGraph.Buckets[graphIndex]), &entry);
            }

            {
                int graphIndex = cast(int)(thisDayIndex - (lastDayAt - GRAPH_WIDTH + 1));
                if (graphIndex >= 0)
                {
                    UpdateStatGroup(&(recentGraph.Buckets[graphIndex]), &entry);
                }
            }
        }
        else
        {
            ++incompleteCount;
        }
    }

    writef("\n%s Statistics\n\n", timingFileName);
    writef("Total complete timings: %d\n", withErrors.Count + noErrors.Count);
    writef("Total incomplete timings: %d\n", incompleteCount);
    writef("Days with timings: %d\n", daysWithTimingCount);
    writef("Days between first and last timing: %d\n", daySpanCount);

    PrintStatGroup("Timings marked successful", noErrors);
    PrintStatGroup("Timings marked failed", withErrors);

    PrintGraph("All", (lastDayAt - firstDayAt), totalGraph);
    PrintGraph("Recent", GRAPH_WIDTH, recentGraph);

    writef("\nTotal time spent: ");

    PrintTime(allMs);

    writef("\n");
}

int main(string[] args)
{
    ulong argCount = args.length;

    ulong entryClock = GetClockInNSecs();

    if (argCount == 3 || argCount == 4)
    {
        import std.algorithm.searching : endsWith;

        string mode = args[1];
        string timingFileName = args[2];
        bool modeIsBegin = mode.endsWith("-begin");
        bool fileExists = timingFileName.exists();

        if (!modeIsBegin)
        {
            assert(fileExists, "Make sure you specify a timing file name.");
        }

        string fileMode = "r+b";
        if (!fileExists)
        {
            fileMode = "w+b";
        }

        File timingFile = File(timingFileName, fileMode);

        scope(exit) timingFile.close();

        timing_file_header header;

        // If the file exists check the magic value.
        if (fileExists)
        {
            if (timingFile.size() == 0)
            {
                timingFile.rawWrite((&MAGIC_VALUE)[0 .. 1]);
                header.MagicValue = MAGIC_VALUE;
            }
            else
            {
                auto input = timingFile.rawRead(new uint[1]);
                header.MagicValue = input[0];

                if (header.MagicValue != MAGIC_VALUE)
                {
                    assert(false, "ERROR: Unable to verify that \"%s\" is actually a dbuildtime (or ctime) compatible file.\n".format(timingFileName));
                }
            }
        }

        if (modeIsBegin)
        {
            // If the file doesn't exist create it, because we're starting a new timing.
            if (!fileExists)
            {
                timingFile.rawWrite((&MAGIC_VALUE)[0 .. 1]);
                header.MagicValue = MAGIC_VALUE;
            }

            timing_file_entry newEntry;

            ulong nanoSeconds = GetClockInNSecs();
            uint milliSeconds = cast(uint)(nanoSeconds / 1_000_000);

            newEntry.StartDate = GetDate();
            newEntry.MillisecondsElapsed = milliSeconds;

            long seekIndex = timingFile.size();

            timingFile.seek(seekIndex, SEEK_SET);

            timingFile.rawWrite((&newEntry)[0 .. 1]);
        }
        else if (mode.endsWith("-end"))
        {
            assert(timingFile.size() > 0, "empty timing file - use -begin first");

            timing_file_entry lastEntry;

            uint timingFileEntrySize = timing_file_entry.sizeof;
            uint timingFileSize = cast(uint)timingFile.size();
            uint seekIndex = timingFileEntrySize > timingFileSize ? timingFileEntrySize : timingFileSize - timingFileEntrySize;

            timingFile.seek(seekIndex, SEEK_SET);

            auto buffer = timingFile.rawRead((&lastEntry)[0 .. 1]);

            assert(!(buffer.length == 0), "could not read last timing file entry");

            if (!(lastEntry.Flags & TFEF_Complete))
            {
                uint startClockD = lastEntry.MillisecondsElapsed;
                uint endClockD = cast(uint)(entryClock / 1_000_000);

                lastEntry.Flags |= TFEF_Complete;
                lastEntry.MillisecondsElapsed = 0;

                if (startClockD < endClockD)
                {
                    uint diffMilliSeconds = endClockD - startClockD;
                    lastEntry.MillisecondsElapsed = diffMilliSeconds;
                }

                if ((argCount == 3) || ((argCount == 4) && (to!int(args[3]) == 0)))
                {
                    lastEntry.Flags |= TFEF_NoErrors;
                }

                timingFile.seek(seekIndex, SEEK_SET);
                timingFile.rawWrite((&lastEntry)[0 .. 1]);

                write("CTIME: ");
                PrintTime(lastEntry.MillisecondsElapsed);
                writef(" (%s)\n", timingFileName);
            }
            else
            {
                stderr.writef("ERROR: Last entry in file \"%s\" is already closed - unbalanced/overlapped calls?\n",
                              timingFileName);
            }
        }
        else if (mode.endsWith("-stats"))
        {
            writeln("stats");
            timing_file_entry[] entries = ReadAllEntries(timingFile);
            Stats(entries, timingFileName);
        }
        else if (mode.endsWith("-csv"))
        {
            writeln("csv");
            timing_file_entry[] entries = ReadAllEntries(timingFile);
            CSV(entries, timingFileName);
        }
        else
        {
            stderr.writef("ERROR: Unrecognized command \"%s\".\n", mode);
            return -3;
        }

        return 0;
    }
    else
    {
        Usage();
        return -1;
    }

}
