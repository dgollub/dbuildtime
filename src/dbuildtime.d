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

// TODO(dkg): make sure we keep the original structs' memory aligments!
//#pragma pack(push,1)
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

double MillisecondDifference(timing_file_date a, timing_file_date b)
{
    //assert(false, "Implement me first!");
    return 0;
}

uint DayIndex(timing_file_date a)
{
    //assert(false, "Implement me first!");
    // convert to SysTime and use .dayOfWeek or .day - not sure
    return 0;
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

timing_file_entry[] ReadAllEntries(File timingFile)
{
    timing_file_entry[] result;

    //long EntriesBegin = timing_file_header.sizeof;
    //long FileSize = fseek(Handle, 0, SEEK_END);
    //if (FileSize > 0)
    //{
    //    long EntriesSize = FileSize - EntriesBegin;
    //    Result.Entries = cast(timing_file_entry * ) malloc(EntriesSize);
    //    if (Result.Entries)
    //    {
    //        long TestPos = fseek(Handle, cast(long)EntriesBegin, SEEK_SET);
    //        long ReadSize = fread(cast(_IO_FILE)Handle, Result.Entries, EntriesSize);
    //        if (ReadSize == EntriesSize)
    //        {
    //            Result.EntryCount = EntriesSize / sizeof(timing_file_entry);
    //        }
    //        else
    //        {
    //            stderr.writef("ERROR: Unable to read timing entries from file.\n");
    //        }
    //    }
    //    else
    //    {
    //        stderr.writef("ERROR: Unable to allocate %d for storing timing entries.\n", EntriesSize);
    //    }
    //}
    //else
    //{
    //    stderr.writef("ERROR: Unable to determine file size of timing file.\n");
    //}

    return result;
}


void CSV(timing_file_entry[] entries, string timingFileName)
{
    //int entryIndex;
    //timing_file_entry* Entry = Array.Entries;

    //writef("%s Timings\n", timingFileName);
    //writef("ordinal, date, duration, status\n");
    //{
    //    for (entryIndex = 0; entryIndex < Array.EntryCount; ++entryIndex, ++Entry)
    //    {
    //        writef("%d, ", entryIndex);
    //        PrintDate(Entry.StartDate);
    //        if (Entry.Flags & TFEF_Complete)
    //        {
    //            writef(", %0.3fs, %s",
    //                cast(double) Entry.MillisecondsElapsed / 1000.0,
    //                (Entry.Flags & TFEF_noErrors) ? "succeeded" : "failed");
    //        }
    //        else
    //        {
    //            writef(", (never completed), failed");
    //        }

    //        writef("\n");
    //    }
    //}
}

struct time_part
{
    string Name;
    double MillisecondsPer;
}

// TODO(dkg): wtf is this? fix this!
void PrintTime(double Milliseconds)
{
    double MillisecondsPerSecond = 1000;
    double MillisecondsPerMinute = 60 * MillisecondsPerSecond;
    double MillisecondsPerHour = 60 * MillisecondsPerMinute;
    double MillisecondsPerDay = 24 * MillisecondsPerHour;
    double MillisecondsPerWeek = 7 * MillisecondsPerDay;
    time_part[] Parts = [
        {
            "week", MillisecondsPerWeek
        },
        {
            "day", MillisecondsPerDay
        },
        {
            "hour", MillisecondsPerHour
        },
        {
            "minute", MillisecondsPerMinute
        },
    ];
    uint PartIndex;
    double Q = Milliseconds;

    for (PartIndex = 0; PartIndex < ((Parts).sizeof / (Parts[0]).sizeof); ++PartIndex)
    {
        uint MsPer = cast(uint)Parts[PartIndex].MillisecondsPer;
        uint This = cast(uint)cast(int)(Q / MsPer);

        if (This > 0)
        {
            writef("%d %s%s, ", cast(int) This, Parts[PartIndex].Name, (This != 1) ? "s" : "");
        }
        Q -= This * MsPer;
    }

    writef("%0.3f seconds", cast(double) Q / 1000.0);
}

void PrintTimeStat(string Name, double Milliseconds)
{
    writef("%s: ", Name);
    PrintTime(Milliseconds);
    write("\n");
}

struct stat_group
{
    uint Count;

    uint SlowestMs;
    uint FastestMs;
    double TotalMs;
}

immutable int GRAPH_HEIGHT = 10;
immutable int GRAPH_WIDTH = 30;

struct graph
{
    stat_group[GRAPH_WIDTH] Buckets;
}

void PrintStatGroup(string Title, stat_group* Group)
{
    uint AverageMs = 0;
    if (Group.Count >= 1)
    {
        AverageMs = cast(uint)(Group.TotalMs / cast(double) Group.Count);
    }

    if (Group.Count > 0)
    {
        writef("%s (%d):\n", Title, Group.Count);
        PrintTimeStat("  Slowest", Group.SlowestMs);
        PrintTimeStat("  Fastest", Group.FastestMs);
        PrintTimeStat("  Average", AverageMs);
        PrintTimeStat("  Total", Group.TotalMs);
    }
}

void UpdateStatGroup(stat_group* Group, timing_file_entry* Entry)
{
    // TODO(dkg): implement this again
    //if (Group.SlowestMs < Entry.MillisecondsElapsed)
    //{
    //    Group.SlowestMs = Entry.MillisecondsElapsed;
    //}

    //if (Group.FastestMs > Entry.MillisecondsElapsed)
    //{
    //    Group.FastestMs = Entry.MillisecondsElapsed;
    //}

    //Group.TotalMs += cast(double) Entry.MillisecondsElapsed;

    //++Group.Count;
}

int MapToDiscrete(double Value, double InMax, double OutMax)
{
    int Result;

    if (InMax == 0)
    {
        InMax = 1;
    }

    Result = cast(int)((Value / InMax) * OutMax);

    return (Result);
}

// TODO(dkg): remove this, this is ugly
void fputc(char s, File f) {
    f.write(s);
}

void PrintGraph(string Title, double daySpan, graph* Graph)
{
    int BucketIndex;
    int LineIndex;
    int MaxCountInBucket = 0;
    uint SlowestMs = 0;
    double DPB = daySpan / cast(double) GRAPH_WIDTH;

    for (BucketIndex = 0; BucketIndex < GRAPH_WIDTH; ++BucketIndex)
    {
        stat_group* Group = &(Graph.Buckets[BucketIndex]);

        if (Group.Count)
        {
            //            double AverageMs = Group->TotalMs / (double)Group->Count;
            if (MaxCountInBucket < Group.Count)
            {
                MaxCountInBucket = Group.Count;
            }

            if (SlowestMs < Group.SlowestMs)
            {
                SlowestMs = Group.SlowestMs;
            }
        }
    }

    writef("\n%s (%f day%s/bucket):\n", Title, DPB, (DPB == 1) ? "" : "s");
    for (LineIndex = GRAPH_HEIGHT - 1; LineIndex >= 0; --LineIndex)
    {
        fputc('|', stdout);
        for (BucketIndex = 0; BucketIndex < GRAPH_WIDTH; ++BucketIndex)
        {
            stat_group* Group = &(Graph.Buckets[BucketIndex]);
            int This = -1;
            if (Group.Count)
            {
                //                double AverageMs = Group->TotalMs / (double)Group->Count;
                This = MapToDiscrete(Group.SlowestMs, SlowestMs, GRAPH_HEIGHT - 1);
            }
            fputc((This >= LineIndex) ? '*' : ' ', stdout);
        }
        if (LineIndex == (GRAPH_HEIGHT - 1))
        {
            fputc(' ', stdout);
            PrintTime(SlowestMs);
        }
        fputc('\n', stdout);
    }
    fputc('+', stdout);
    for (BucketIndex = 0; BucketIndex < GRAPH_WIDTH; ++BucketIndex)
    {
        fputc('-', stdout);
    }
    fputc(' ', stdout);
    PrintTime(0);
    fputc('\n', stdout);
    fputc('\n', stdout);
    for (LineIndex = GRAPH_HEIGHT - 1; LineIndex >= 0; --LineIndex)
    {
        fputc('|', stdout);
        for (BucketIndex = 0; BucketIndex < GRAPH_WIDTH; ++BucketIndex)
        {
            stat_group* Group = &(Graph.Buckets[BucketIndex]);
            int This = -1;
            if (Group.Count)
            {
                This = MapToDiscrete(Group.Count, MaxCountInBucket, GRAPH_HEIGHT - 1);
            }
            fputc((This >= LineIndex) ? '*' : ' ', stdout);
        }
        if (LineIndex == (GRAPH_HEIGHT - 1))
        {
            writef(" %d", MaxCountInBucket);
        }
        fputc('\n', stdout);
    }
    fputc('+', stdout);
    for (BucketIndex = 0; BucketIndex < GRAPH_WIDTH; ++BucketIndex)
    {
        fputc('-', stdout);
    }
    writef(" 0\n");
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

    graph totalGraph;
    graph recentGraph;

    withErrors.FastestMs = 0xFFFFFFFF;
    noErrors.FastestMs = 0xFFFFFFFF;

    if (entries.length >= 2)
    {
        double milliD = MillisecondDifference(entries[$-1].StartDate, entries[0].StartDate);
        daySpanCount = cast(uint)(milliD / (1000.0 * 60.0 * 60.0 * 24.0));

        firstDayAt = cast(double) DayIndex(entries[0].StartDate);
        lastDayAt = cast(double) DayIndex(entries[$-1].StartDate);
        daySpan = (lastDayAt - firstDayAt);
    }
    daySpan += 1;

    // TODO(dkg): use a nicer loop syntax!
    for (int entryIndex = 0; entryIndex < entries.length; ++entryIndex)
    {
        auto entry = entries[entryIndex];
        if (entry.Flags & TFEF_Complete)
        {
            stat_group* Group = (entry.Flags & TFEF_NoErrors) ?  &noErrors : &withErrors;

            uint ThisDayIndex = DayIndex(entry.StartDate);
            if (lastDayIndex != ThisDayIndex)
            {
                lastDayIndex = ThisDayIndex;
                ++daysWithTimingCount;
            }

            UpdateStatGroup(Group, &entry);
            UpdateStatGroup(&allStats, &entry);

            allMs += cast(double)entry.MillisecondsElapsed;

            {
                int graphIndex = cast(int)((cast(double)(ThisDayIndex - firstDayAt) / daySpan) * cast(double) GRAPH_WIDTH);
                UpdateStatGroup(&(totalGraph.Buckets[graphIndex]), &entry);
            }

            {
                int graphIndex = cast(int)(ThisDayIndex - (lastDayAt - GRAPH_WIDTH + 1));
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
    PrintStatGroup("Timings marked successful",  & noErrors);
    PrintStatGroup("Timings marked failed",  & withErrors);

    PrintGraph("All", (lastDayAt - firstDayAt),  & totalGraph);
    PrintGraph("Recent", GRAPH_WIDTH,  & recentGraph);

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
        }

        return 0;
    }
    else
    {
        Usage();
        return -1;
    }

}
