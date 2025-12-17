Always end a Live Activity immediately when the task or event ends, and consider setting a custom dismissal time. When a Live Activity ends, the system immediately removes it from the Dynamic Island and in CarPlay. On the Lock Screen, in the Mac menu bar, and the watchOS Smart Stack, it remains for up to four hours. Depending on the Live Activity, showing a summary may only be relevant for a brief time after it ends. Consider choosing a custom dismissal time that’s proportional to the duration of your Live Activity. In most cases, 15 to 30 minutes is adequate. For example, a rideshare app could end its Live Activity when a ride completes and remain visible for 30 minutes to allow people to view the ride summary and leave a tip. For developer guidance, refer to Displaying live data with Live Activities.

Presentation

Your Live Activity needs to support all locations, devices, and their corresponding appearances. Because it appears across systems at different dimensions, create Live Activity layouts that best support each place they appear.

Start with the iPhone design, then refine it for other contexts. Create standard designs for each presentation first. Then, depending on the functionality that your Live Activity provides, design additional custom layouts for specific contexts like iPhone in StandBy, CarPlay, or Apple Watch. For more information about custom layouts, refer to StandBy, CarPlay, and watchOS.

Compact presentation

Focus on the most important information. Use the compact presentation to show dynamic, up-to-date information that’s essential to the Live Activity and easy to understand. For example, a sports app could display two team logos and the score.

Ensure unified information and design of the compact presentations in the Dynamic Island. Though the TrueDepth camera separates the leading and trailing elements, design them to read as a single piece of information, and use consistent color and typography to help create a connection between both elements.

Keep content as narrow as possible and ensure it’s snug against the TrueDepth camera. Try not to obscure key information in the status bar, and don’t add padding between content and the TrueDepth camera. Maintain a balanced layout with similarly sized views for both leading and trailing elements; for example, use shortened units or less precise data to maintain appropriate width and balance.

Link to relevant app content. When people tap a compact Live Activity, open your app directly to the related details. Ensure both leading and trailing elements link to the same screen.

Minimal presentation

Ensure that your Live Activity is recognizable in the minimal presentation. If possible, display updated information rather than just a logo, while ensuring people can quickly recognize your app. For example, the Timer app’s minimal Live Activity presentation displays the remaining time instead of a static icon.

Expanded presentation

Maintain the relative placement of elements to create a coherent layout between presentations. The expanded presentation is an enlarged version of the compact or minimal presentation. Ensure information and layouts expand predictably when the Live Activity expands.

Wrap content tightly around the TrueDepth camera. Arrange content close to the TrueDepth camera, and try to avoid leaving too much room around it to use space more efficiently and to help diminish the camera’s presence.

Lock Screen presentation

Don’t replicate notification layouts. Create a unique layout that’s specific to the information that appears in the Live Activity.

Choose colors that work well on a personalized Lock Screen. People customize their Lock Screen with wallpapers, custom tint colors, and widgets. To make a Live Activity fit a custom Lock Screen aesthetic while remaining legible, use custom background or tint colors and opacity sparingly.

Make sure your design, assets, and colors look great and offer enough contrast in Dark Mode and on an Always-On display. By default, a Live Activity on the Lock Screen uses a light background color in the light appearance and a dark background color in the dark appearance. If you use a custom background color, choose a color that works well in both modes or a different color for each appearance. Verify your choices on a device with an Always-On display with reduced luminance because the system adapts colors as needed in this appearance. For guidance, see Dark Mode and Always On; for developer guidance, see About asset catalogs.

Verify the generated color of the dismiss button. The system automatically generates a matching dismiss button based on the background and foreground colors of your Live Activity. Verify that the generated color matches your design and adjust it if needed using activitySystemActionForegroundColor(_:).

Use standard margins to align your design with notifications. The standard layout margin for Live Activities on the Lock Screen is 14 points. While tighter margins may be appropriate for elements like graphics or buttons, avoid crowding the edges and creating a cluttered appearance. For developer guidance, see padding(_:_:).

StandBy presentation

Update your layout for StandBy. Make sure assets look great at the larger scale, and consider creating a custom layout that makes use of the extra space. For developer guidance, see Creating custom views for Live Activities.

Consider using the default background color in StandBy. The default background color seamlessly blends your Live Activity with the device bezel, achieves a softer look that integrates with a person’s surroundings, and allows the system to scale the Live Activity slightly larger because it doesn’t need to account for the margins around the TrueDepth camera.

Use standard margins and avoid extending graphic elements to the edge of the screen. Without standard margins, content gets cut off as the Live Activity extends, making it feel broken.

Verify your design in Night Mode. In Night Mode, the system applies a red tint to your Live Activity. Check that your Live Activity design uses colors that provide enough contrast in Night Mode.

CarPlay

In CarPlay, the system automatically combines the leading and trailing elements of the compact presentation into a single layout that appears on CarPlay Dashboard.

Your Live Activity design applies to both CarPlay and Apple Watch, so design for both contexts. While Live Activities on Apple Watch can be interactive, the system deactivates interactive elements in CarPlay. For more information, refer to watchOS below. For developer guidance, refer to Creating custom views for Live Activities.

Consider creating a custom layout if your Live Activity would benefit from larger text or additional information. Instead of using the default appearance in CarPlay, declare support for a ActivityFamily.small supplemental activity family.

Carefully consider including buttons or toggles in your custom layout. In CarPlay, the system deactivates interactive elements in your Live Activity. If people are likely to start or observe your Live Activity while driving, prefer displaying timely content rather than buttons and toggles.

Platform considerations

No additional considerations for iOS or iPadOS. Not supported in tvOS or visionOS.

macOS

Active Live Activities automatically appear in the Menu bar of a paired Mac using the compact, minimal, and expanded presentations. Clicking the Live Activity launches iPhone Mirroring to display your app.

watchOS

When a Live Activity begins on iPhone, it appears on a paired Apple Watch at the top of the Smart Stack. By default, the view displayed in the Smart Stack combines the leading and trailing elements from the Live Activity’s compact presentation on iPhone.

If you offer a watchOS app and someone taps the Live Activity in the Smart Stack, it opens your watchOS app. Without a watchOS app, tapping opens a full-screen view with a button to open your app on the paired iPhone.

Consider creating a custom watchOS layout. While the system provides a default view automatically, a custom layout designed for Apple Watch can show more information and add interactive functionality like a button or toggle.

Carefully consider including buttons or toggles in your custom layout. The custom watchOS layout also applies to your Live Activity in CarPlay where the system deactivates interactive elements. If people are likely to start or observe your Live Activity while driving, don’t include buttons or toggles in your custom watchOS layout. For developer guidance, see Creating custom views for Live Activities.

iPhone compact view

Default Smart Stack view

Custom Smart Stack view

Focus on essential information and significant updates. Use space in the Smart Stack as efficiently as possible and think of the most useful information that a Live Activity can convey:

Progress, like the estimated arrival time of a delivery

Interactive elements, like stopwatch or timer controls

Significant updates, like sports score changes

Specifications

When you design your Live Activities, use the following values for guidance.

CarPlay dimensions

The system may scale your Live Activity to best fit a vehicle’s screen size and resolution. Use the listed values to verify your design:
