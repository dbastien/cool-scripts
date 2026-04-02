using System.Management.Automation;
using System.Management.Automation.Language;
using System.Management.Automation.Subsystem.Prediction;

namespace CdPathPredictor;

public sealed class RealCdPredictor : ICommandPredictor
{
    private static readonly TimeSpan CacheLifetime = TimeSpan.FromMilliseconds(200);
    private static readonly object CacheLock = new();
    private static CacheEntry? _cache;

    private readonly Guid _id;

    public RealCdPredictor(Guid id)
    {
        _id = id;
    }

    public Guid Id => _id;

    public string Name => "RealCdPath";

    public string Description => "Predicts Set-Location targets under the current directory using PowerShell completion and ProviderContainer matches.";

    public SuggestionPackage GetSuggestion(PredictionClient client, PredictionContext context, CancellationToken cancellationToken)
    {
        if (!TryGetLocationCommand(context, out var commandAst))
        {
            return default;
        }

        var originalInput = context.InputAst.Extent.Text;
        var needsSyntheticSpace = commandAst.CommandElements.Count == 1 && !EndsWithWhitespace(originalInput);
        var completionContext = needsSyntheticSpace ? PredictionContext.Create(originalInput + " ") : context;
        var currentDirectory = GetCacheDirectory();
        var cacheKey = new CacheKey(currentDirectory, completionContext.InputAst.Extent.Text, completionContext.CursorPosition);

        if (TryGetCachedSuggestions(cacheKey, out var cachedSuggestions))
        {
            return cachedSuggestions.Length == 0 ? default : new SuggestionPackage(cachedSuggestions);
        }

        var completion = CommandCompletion.CompleteInput(
            completionContext.InputAst,
            completionContext.InputTokens,
            completionContext.CursorPosition,
            options: null);

        if (completion is null || completion.CompletionMatches.Count == 0 || cancellationToken.IsCancellationRequested)
        {
            StoreCachedSuggestions(cacheKey, Array.Empty<PredictiveSuggestion>());
            return default;
        }

        var baseInput = completionContext.InputAst.Extent.Text;
        var prefix = baseInput[..completion.ReplacementIndex];
        var suggestions = new List<PredictiveSuggestion>(capacity: Math.Min(24, completion.CompletionMatches.Count));
        var seen = new HashSet<string>(StringComparer.OrdinalIgnoreCase);

        foreach (var match in completion.CompletionMatches)
        {
            if (cancellationToken.IsCancellationRequested)
            {
                return default;
            }

            if (match.ResultType != CompletionResultType.ProviderContainer)
            {
                continue;
            }

            if (!TryResolveDirectoryPath(match.CompletionText, currentDirectory, out var resolvedTarget)
                || !IsStrictSubdirectoryOf(resolvedTarget, currentDirectory))
            {
                continue;
            }

            var suggestionText = prefix + match.CompletionText;
            if (string.Equals(suggestionText, baseInput, StringComparison.OrdinalIgnoreCase))
            {
                continue;
            }

            if (!seen.Add(suggestionText))
            {
                continue;
            }

            var toolTip = string.Equals(match.CompletionText, match.ToolTip, StringComparison.Ordinal)
                ? null
                : match.ToolTip;

            suggestions.Add(new PredictiveSuggestion(suggestionText, toolTip));

            if (suggestions.Count == 24)
            {
                break;
            }
        }

        var cached = suggestions.ToArray();
        StoreCachedSuggestions(cacheKey, cached);
        return cached.Length == 0 ? default : new SuggestionPackage(cached);
    }

    public bool CanAcceptFeedback(PredictionClient client, PredictorFeedbackKind feedback) => false;

    public void OnSuggestionDisplayed(PredictionClient client, uint session, int countOrIndex)
    {
    }

    public void OnSuggestionAccepted(PredictionClient client, uint session, string acceptedSuggestion)
    {
    }

    public void OnCommandLineAccepted(PredictionClient client, IReadOnlyList<string> history)
    {
    }

    public void OnCommandLineExecuted(PredictionClient client, string commandLine, bool success)
    {
    }

    private static bool TryGetLocationCommand(PredictionContext context, out CommandAst commandAst)
    {
        commandAst = null!;

        var relatedAstCount = context.RelatedAsts.Count;
        if (relatedAstCount == 0)
        {
            return false;
        }

        var lastAst = context.RelatedAsts[relatedAstCount - 1];
        commandAst = lastAst as CommandAst ?? lastAst.Parent as CommandAst;
        if (commandAst is null)
        {
            return false;
        }

        var commandElementCount = commandAst.CommandElements.Count;
        if (commandElementCount == 0)
        {
            return false;
        }

        if (commandAst.CommandElements[0] is not StringConstantExpressionAst commandName)
        {
            return false;
        }

        var commandValue = commandName.Value;
        return commandValue.Equals("cd", StringComparison.OrdinalIgnoreCase)
            || commandValue.Equals("sl", StringComparison.OrdinalIgnoreCase)
            || commandValue.Equals("Set-Location", StringComparison.OrdinalIgnoreCase);
    }

    private static bool TryGetCachedSuggestions(CacheKey cacheKey, out PredictiveSuggestion[] suggestions)
    {
        lock (CacheLock)
        {
            if (_cache is not null
                && _cache.Key == cacheKey
                && DateTimeOffset.UtcNow - _cache.CreatedAt <= CacheLifetime)
            {
                suggestions = _cache.Suggestions;
                return true;
            }
        }

        suggestions = Array.Empty<PredictiveSuggestion>();
        return false;
    }

    private static void StoreCachedSuggestions(CacheKey cacheKey, PredictiveSuggestion[] suggestions)
    {
        lock (CacheLock)
        {
            _cache = new CacheEntry(cacheKey, DateTimeOffset.UtcNow, suggestions);
        }
    }

    private static string GetCacheDirectory()
    {
        try
        {
            return Environment.CurrentDirectory ?? string.Empty;
        }
        catch
        {
            return string.Empty;
        }
    }

    private static bool EndsWithWhitespace(string text)
    {
        return text.Length > 0 && char.IsWhiteSpace(text[^1]);
    }

    /// <summary>
    /// Maps completion text to a real filesystem directory path (process cwd must match PowerShell location).
    /// </summary>
    private static bool TryResolveDirectoryPath(string completionText, string currentDirectory, out string fullPath)
    {
        fullPath = string.Empty;
        if (string.IsNullOrWhiteSpace(completionText))
        {
            return false;
        }

        var t = completionText.TrimEnd('/', '\\');
        var providerSep = t.IndexOf("::", StringComparison.Ordinal);
        if (providerSep >= 0 && providerSep + 2 < t.Length)
        {
            t = t[(providerSep + 2)..];
        }

        try
        {
            fullPath = Path.IsPathFullyQualified(t)
                ? Path.GetFullPath(t)
                : Path.GetFullPath(Path.Combine(currentDirectory, t));
            return Directory.Exists(fullPath);
        }
        catch
        {
            return false;
        }
    }

    /// <summary>
    /// True only if <paramref name="childFullPath"/> is a proper subdirectory of <paramref name="parentFullPath"/>,
    /// so we do not suggest jumping to unrelated trees (e.g. /bar when cwd is /foo).
    /// </summary>
    private static bool IsStrictSubdirectoryOf(string childFullPath, string parentFullPath)
    {
        try
        {
            var par = Path.GetFullPath(parentFullPath);
            var chi = Path.GetFullPath(childFullPath);
            if (!par.EndsWith(Path.DirectorySeparatorChar) && !par.EndsWith(Path.AltDirectorySeparatorChar))
            {
                par += Path.DirectorySeparatorChar;
            }

            var cmp = OperatingSystem.IsWindows()
                ? StringComparison.OrdinalIgnoreCase
                : StringComparison.Ordinal;
            return chi.StartsWith(par, cmp) && chi.Length > par.Length;
        }
        catch
        {
            return false;
        }
    }

    private sealed record CacheEntry(CacheKey Key, DateTimeOffset CreatedAt, PredictiveSuggestion[] Suggestions);

    private readonly record struct CacheKey(string CurrentDirectory, string Input, int CursorPosition);
}
