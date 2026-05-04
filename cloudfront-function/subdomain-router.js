function handler(event) {
    var request = event.request;

    if (!request.headers.host || !request.headers.host.value) {
        return {
            statusCode: 400,
            statusDescription: 'Bad Request',
        };
    }

    var host = request.headers.host.value;

    // Extract PR number from subdomain (e.g., pr-123.test.infrademo.vydev.io)
    var prMatch = host.match(/^pr-(\d+)\./);

    if (!prMatch) {
        return {
            statusCode: 404,
            statusDescription: 'Not Found',
        };
    }

    var prNumber = prMatch[1];
    var uri = request.uri;

    // Rewrite URI to include PR prefix
    // e.g., /index.html -> /pr-123/index.html
    if (uri === '/' || uri === '') {
        request.uri = '/pr-' + prNumber + '/index.html';
    } else {
        request.uri = '/pr-' + prNumber + uri;
    }

    return request;
}
