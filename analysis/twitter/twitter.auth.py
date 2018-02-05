import tweepy

consumer_token = "GG3j4A0jpSGXBt9D7aM4QzdBV"
consumer_secret = "SsYRzE2on0xLWwPZ70Mi7YUabcaBaoohUFYlyEVjiw7mF5cFGB"

def get_user_tokens(consumer_token, consumer_secret):
    auth = tweepy.OAuthHandler(consumer_token, consumer_secret)
    print "Navigate to the following webpage and authorize your application"
    print(auth.get_authorization_url())
    pin = raw_input("Enter the PIN acquired on Twitter website: ").strip()
    token = auth.get_access_token(verifier=pin)
    access_token = token[0]
    token_secret = token[1]
    print "With the following tokens, your application should be able to make requests on behalf of the specific user"
    print "Access token: %s" % access_token
    print "Token secret: %s" % token_secret
    return access_token, token_secret

access_token, token_secret = get_user_tokens(consumer_token, consumer_secret)