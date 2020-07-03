//
//  ChannelListPage.swift
//  Puffery
//
//  Created by Valentin Knabel on 18.04.20.
//  Copyright © 2020 Valentin Knabel. All rights reserved.
//

import Combine
import SwiftUI

enum ChannelSelection: Hashable {
    case all
    case channel(Channel)
}

struct ChannelListPage: View {
    private var api: API { Current.api }

    @State var presentsSettings = false
    @State var presentsChannelCreation = false
    @State var presentsChannelSubscription = false
    @State var shouldReload = PassthroughSubject<Void, FetchingError>()
    @State var selection: ChannelSelection? = UIDevice.current.model == "iPad"
        ? .all
        : nil

    var body: some View {
        ZStack {
            List {
                Section {
                    NavigationLink(destination: ChannelDetailsPage(), tag: .all, selection: $selection) {
                        Text("ChannelList.All")
                    }
                }

                Section(header: createChannelHeader()) {
                    Fetching(loadOwnChannelsPublisher, empty: self.noChannelsFound()) { channels in
                        ForEach(channels) { channel in
                            NavigationLink(destination: ChannelDetailsPage(channel: channel), tag: .channel(channel), selection: self.$selection) {
                                Text(channel.title)
                            }
                        }
                    }
                }

                Section(header: subscribeChannelHeader()) {
                    Fetching(loadSharedChannelsPublisher, empty: self.noChannelsFound()) { channels in
                        ForEach(channels) { channel in
                            NavigationLink(destination: ChannelDetailsPage(channel: channel), tag: .channel(channel), selection: self.$selection) {
                                Text(channel.title)
                            }
                        }
                    }
                }
            }.roundedListStyle()
        }
        .navigationBarTitle("ChannelList.Title")
        .navigationBarItems(trailing: settingsNavigationBarItem)
        .trackAppearence("channels", using: Current.tracker)
    }

    func createChannelHeader() -> some View {
        channelsHeader("ChannelList.OwnChannels.SectionTitle", actionText: "ChannelList.OwnChannels.New", action: { self.presentsChannelCreation.toggle() })
            .sheet(isPresented: $presentsChannelCreation, onDismiss: shouldReload.send) {
                NavigationView {
                    ChannelCreationPage()
                }.navigationViewStyle(StackNavigationViewStyle())
            }
    }

    func subscribeChannelHeader() -> some View {
        channelsHeader("ChannelList.SubscribeChannels.SectionTitle", actionText: "ChannelList.SubscribeChannels.New", action: { self.presentsChannelSubscription.toggle() })
            .sheet(isPresented: $presentsChannelSubscription, onDismiss: shouldReload.send) {
                NavigationView {
                    ChannelSubscribingPage()
                }.navigationViewStyle(StackNavigationViewStyle())
            }
    }

    func channelsHeader(_ title: LocalizedStringKey, actionText: LocalizedStringKey, action: @escaping () -> Void) -> some View {
        HStack {
            Text(title)
            Spacer()

            Button(action: action) {
                HStack {
                    Text(actionText)
                    Image(systemName: "plus.circle").font(.body)
                }
            }
        }
    }

    func noChannelsFound(_ emptyTitle: LocalizedStringKey = "ChannelList.NoChannels") -> some View {
        HStack {
            Spacer()
            Text(emptyTitle).opacity(0.5)
            Spacer()
        }
    }

    var settingsNavigationBarItem: some View {
        Button(action: { self.presentsSettings.toggle() }) {
            Image(systemName: "person.crop.circle").font(.system(size: 21))
        }.sheet(isPresented: $presentsSettings) {
            NavigationView {
                AppSettingsPage()
            }.navigationViewStyle(StackNavigationViewStyle())
        }
    }

    var didUnsubscribedFromChannel = NotificationCenter.default.publisher(for: .didUnsubscribeFromChannel)
        .transformError(to: FetchingError.self)
        .transform(to: ())
    var didSubscribeToChannel = NotificationCenter.default.publisher(for: .didSubscribeToChannel)
        .transformError(to: FetchingError.self)
        .transform(to: ())
    var didChangeChannel = NotificationCenter.default.publisher(for: .didChangeChannel)
        .transformError(to: FetchingError.self)
        .transform(to: ())

    var loadOwnChannelsPublisher: AnyPublisher<[Channel], FetchingError> {
        shouldReload.merge(with: didUnsubscribedFromChannel)
            .merge(with: didSubscribeToChannel)
            .merge(with: didChangeChannel)
            .prepend(())
            .flatMap(api.ownChannels().publisher)
            .receive(on: DispatchQueue.main)
            .eraseToAnyPublisher()
    }

    var loadSharedChannelsPublisher: AnyPublisher<[Channel], FetchingError> {
        shouldReload.merge(with: didUnsubscribedFromChannel)
            .merge(with: didSubscribeToChannel)
            .merge(with: didChangeChannel)
            .prepend(())
            .flatMap(api.sharedChannels().publisher)
            .receive(on: DispatchQueue.main)
            .eraseToAnyPublisher()
    }
}

#if DEBUG
    struct ChannelListPage_Previews: PreviewProvider {
        static var previews: some View {
            NavigationView {
                ChannelListPage()
            }
        }
    }
#endif
