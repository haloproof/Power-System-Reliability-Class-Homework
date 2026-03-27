function over_branch = overload(results)
    thresh = results.branch(:,6);
    S_from = sqrt(results.branch(:,14) .^2 + results.branch(:,15) .^2);
    S_to = sqrt(results.branch(:,16) .^2 + results.branch(:,17) .^2);
    overload = (S_from > thresh) | (S_to > thresh);
    overload = overload .* (1:size(results.branch, 1))';
    over_branch = [results.branch overload];
end    